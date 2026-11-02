#![forbid(unsafe_code)]

use std::collections::HashMap;

use anyhow::{Context, Result, ensure};
use flutter_rust_bridge::frb;
use html5ever::{parse_document, tendril::TendrilSink};
use markup5ever_rcdom::{Handle, NodeData, RcDom};
use xmlparser::{ElementEnd, Token, Tokenizer};

/// The same arena columns as Pagecraft's ContentDocument, transferred as typed arrays.
#[derive(Default, Debug)]
pub struct NativeDocument {
    pub kinds: Vec<u8>,
    pub parents: Vec<i32>,
    pub first_children: Vec<i32>,
    pub last_children: Vec<i32>,
    pub next_siblings: Vec<i32>,
    pub previous_siblings: Vec<i32>,
    pub child_counts: Vec<i32>,
    pub names: Vec<i32>,
    pub attribute_starts: Vec<i32>,
    pub attribute_counts: Vec<i32>,
    pub qualified_names: Vec<String>,
    pub attribute_names: Vec<String>,
    pub attribute_values: Vec<String>,
    pub texts: Vec<String>,
}

#[derive(Default)]
#[frb(ignore)]
struct Builder {
    data: NativeDocument,
    open: Vec<(usize, String)>,
    name_ids: HashMap<String, i32>,
    namespaces: bool,
}

impl Builder {
    fn node(&mut self, kind: u8, name: i32) -> Result<usize> {
        let data = &mut self.data;
        let index = data.kinds.len();
        ensure!(index < 10_000_000, "Markup node limit exceeded");
        let parent = self.open.last().map_or(-1, |(i, _)| *i as i32);
        data.kinds.push(kind);
        data.parents.push(parent);
        data.first_children.push(-1);
        data.last_children.push(-1);
        data.next_siblings.push(-1);
        data.previous_siblings.push(-1);
        data.child_counts.push(0);
        data.names.push(name);
        data.attribute_starts
            .push(data.attribute_names.len() as i32);
        data.attribute_counts.push(0);
        if parent >= 0 {
            let parent = parent as usize;
            let last = data.last_children[parent];
            if last < 0 {
                data.first_children[parent] = index as i32;
            } else {
                data.next_siblings[last as usize] = index as i32;
                data.previous_siblings[index] = last;
            }
            data.last_children[parent] = index as i32;
            data.child_counts[parent] += 1;
        }
        Ok(index)
    }

    fn start(&mut self, name: String, attributes: Vec<(String, String)>) -> Result<()> {
        ensure!(
            !self.open.is_empty() || self.data.kinds.is_empty(),
            "Multiple markup root elements"
        );
        let name_id = *self.name_ids.entry(name.clone()).or_insert_with(|| {
            self.data.qualified_names.push(name.clone());
            (self.data.qualified_names.len() - 1) as i32
        });
        let index = self.node(0, name_id)?;
        for (key, value) in attributes {
            if !self.namespaces && (key == "xmlns" || key.starts_with("xmlns:")) {
                continue;
            }
            self.data.attribute_names.push(key);
            self.data.attribute_values.push(value);
            self.data.attribute_counts[index] += 1;
        }
        self.open.push((index, name));
        Ok(())
    }

    fn end(&mut self, name: Option<&str>) -> Result<()> {
        let (_, current) = self
            .open
            .pop()
            .context("Unexpected markup closing element")?;
        ensure!(
            name.is_none_or(|name| name == current),
            "Mismatched markup closing element"
        );
        Ok(())
    }

    fn text(&mut self, value: String, cdata: bool) -> Result<()> {
        if self.open.is_empty() {
            return Ok(());
        }
        let index = self.data.texts.len() as i32;
        self.data.texts.push(value);
        self.node(if cdata { 2 } else { 1 }, index)?;
        Ok(())
    }

    fn finish(self) -> Result<NativeDocument> {
        ensure!(self.open.is_empty(), "Unclosed markup element");
        ensure!(!self.data.kinds.is_empty(), "No markup root element");
        Ok(self.data)
    }
}

fn qualified(prefix: &str, local: &str) -> String {
    if prefix.is_empty() {
        local.to_owned()
    } else {
        format!("{prefix}:{local}")
    }
}

fn line_breaks(value: &str) -> String {
    value.replace("\r\n", "\n").replace('\r', "\n")
}

fn text_value(value: &str) -> String {
    line_breaks(&html_escape::decode_html_entities(value))
}

/// Namespace-preserving mode matches package:xml's FB2 DOM whitespace.
/// The other mode matches ContentDocument's browser-style arena.
#[frb(sync)]
pub fn parse_xml(text: String, namespaces: bool) -> Result<NativeDocument> {
    parse_xml_impl(&text, namespaces)
}

/// Includes dispatch through the FRB worker pool in the benchmark.
pub fn parse_xml_async(text: String, namespaces: bool) -> Result<NativeDocument> {
    parse_xml_impl(&text, namespaces)
}

fn parse_xml_impl(text: &str, namespaces: bool) -> Result<NativeDocument> {
    let mut builder = Builder {
        namespaces,
        ..Builder::default()
    };
    let mut pending: Option<(String, Vec<(String, String)>)> = None;
    for token in Tokenizer::from(text) {
        match token? {
            Token::ElementStart { prefix, local, .. } => {
                ensure!(pending.is_none(), "Unclosed markup start tag");
                pending = Some((qualified(prefix.as_str(), local.as_str()), Vec::new()));
            }
            Token::Attribute {
                prefix,
                local,
                value,
                ..
            } => {
                let (_, attributes) = pending.as_mut().context("Attribute outside an element")?;
                let name = qualified(prefix.as_str(), local.as_str());
                ensure!(
                    !attributes.iter().any(|(key, _)| key == &name),
                    "Duplicate XML attribute"
                );
                let normalized = if namespaces {
                    value.as_str().to_owned()
                } else {
                    line_breaks(value.as_str()).replace(['\n', '\t'], " ")
                };
                attributes.push((
                    name,
                    html_escape::decode_html_entities(&normalized).into_owned(),
                ));
            }
            Token::ElementEnd { end, .. } => match end {
                ElementEnd::Open => {
                    let (name, attributes) = pending.take().context("Missing element start")?;
                    builder.start(name, attributes)?;
                }
                ElementEnd::Empty => {
                    let (name, attributes) = pending.take().context("Missing element start")?;
                    builder.start(name, attributes)?;
                    builder.end(None)?;
                }
                ElementEnd::Close(prefix, local) => {
                    builder.end(Some(&qualified(prefix.as_str(), local.as_str())))?
                }
            },
            Token::Text { text } => builder.text(
                if namespaces {
                    html_escape::decode_html_entities(text.as_str()).into_owned()
                } else {
                    text_value(text.as_str())
                },
                false,
            )?,
            Token::Cdata { text, .. } => builder.text(
                if namespaces {
                    text.as_str().to_owned()
                } else {
                    line_breaks(text.as_str())
                },
                true,
            )?,
            _ => {}
        }
    }
    ensure!(pending.is_none(), "Unclosed markup start tag");
    builder.finish()
}

#[frb(sync)]
pub fn parse_html(text: String) -> Result<NativeDocument> {
    let dom = parse_document(RcDom::default(), Default::default()).one(text);
    enum Action {
        Visit(Handle),
        End,
    }
    let mut work = vec![Action::Visit(dom.document.clone())];
    let mut builder = Builder::default();
    while let Some(action) = work.pop() {
        match action {
            Action::End => builder.end(None)?,
            Action::Visit(node) => {
                match &node.data {
                    NodeData::Element { name, attrs, .. } => {
                        let attributes = attrs
                            .borrow()
                            .iter()
                            .map(|attr| {
                                (
                                    qualified(
                                        attr.name.prefix.as_ref().map_or("", |p| p.as_ref()),
                                        attr.name.local.as_ref(),
                                    ),
                                    attr.value.to_string(),
                                )
                            })
                            .collect();
                        builder.start(name.local.to_string(), attributes)?;
                        work.push(Action::End);
                    }
                    NodeData::Text { contents } => {
                        builder.text(line_breaks(contents.borrow().as_ref()), false)?;
                        continue;
                    }
                    NodeData::Document => {}
                    _ => continue,
                }
                for child in node.children.borrow().iter().rev() {
                    work.push(Action::Visit(child.clone()));
                }
            }
        }
    }
    builder.finish()
}

pub fn parse_html_async(text: String) -> Result<NativeDocument> {
    parse_html(text)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn xml_keeps_text_and_cdata_separate() -> Result<()> {
        let data = parse_xml_impl("<p id='x'>a<![CDATA[b]]><i/>c</p>", false)?;
        assert_eq!(data.kinds, [0, 1, 2, 0, 1]);
        assert_eq!(data.parents, [-1, 0, 0, 0, 0]);
        assert_eq!(data.texts, ["a", "b", "c"]);
        assert_eq!(data.first_children, [1, -1, -1, -1, -1]);
        Ok(())
    }

    #[test]
    fn xml_attribute_references_keep_their_line_breaks() -> Result<()> {
        let data = parse_xml_impl("<p a='x\r\ny\tz&#xD;&#xA;'>&nbsp;</p>", false)?;
        assert_eq!(data.attribute_values, ["x y z\r\n"]);
        assert_eq!(data.texts, ["\u{a0}"]);
        Ok(())
    }

    #[test]
    fn malformed_xml_returns_errors() {
        for text in ["", "<p>", "<p></x>", "<p/><p/>", "<p a='x' a='y'/>"] {
            assert!(parse_xml_impl(text, false).is_err(), "{text}");
        }
    }

    #[test]
    fn html_adds_the_browser_roots() -> Result<()> {
        let data = parse_html("<p>A &amp; B<br>tail".into())?;
        assert_eq!(data.qualified_names, ["html", "head", "body", "p", "br"]);
        assert_eq!(data.texts, ["A & B", "tail"]);
        Ok(())
    }
}
