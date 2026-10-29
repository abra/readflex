#![forbid(unsafe_code)]

use std::fs::File;
use std::io::{Read, Seek, SeekFrom};

use anyhow::{Context, Result, ensure};
use flutter_rust_bridge::frb;

use crate::mobi_decoder::Decoder;

#[derive(Clone, Debug)]
pub struct ByteRange {
    pub offset: u64,
    pub length: u64,
}

#[frb(opaque)]
pub struct NativeFile {
    file: File,
    length: u64,
    decoder: Option<Decoder>,
    compression: Option<u16>,
    trailing_flags: u32,
}

impl NativeFile {
    pub fn open(path: String) -> Result<Self> {
        let file = File::open(path)?;
        let length = file.metadata()?.len();
        Ok(Self {
            file,
            length,
            decoder: None,
            compression: None,
            trailing_flags: 0,
        })
    }

    #[frb(sync)]
    pub fn length(&self) -> u64 {
        self.length
    }

    pub fn read_at(&mut self, range: ByteRange) -> Result<Vec<u8>> {
        ensure!(range.offset <= self.length, "File offset past the end");
        let length = usize::try_from(range.length.min(self.length - range.offset))?;
        ensure!(
            length <= 512 * 1024 * 1024,
            "Benchmark read exceeds 512 MiB"
        );
        let mut bytes = vec![0; length];
        self.file.seek(SeekFrom::Start(range.offset))?;
        self.file.read_exact(&mut bytes)?;
        Ok(bytes)
    }

    pub fn configure_mobi(
        &mut self,
        compression: u16,
        dictionary_ranges: Vec<ByteRange>,
        trailing_flags: u32,
    ) -> Result<()> {
        let records = dictionary_ranges
            .into_iter()
            .map(|range| self.read_at(range))
            .collect::<Result<Vec<_>>>()?;
        self.decoder = if compression == 1 {
            None
        } else {
            Some(Decoder::load(compression, &records)?)
        };
        self.compression = Some(compression);
        self.trailing_flags = trailing_flags;
        Ok(())
    }

    pub fn read_mobi_record(&mut self, range: ByteRange) -> Result<Vec<u8>> {
        let bytes = self.read_at(range)?;
        let bytes = strip_trailing(&bytes, self.trailing_flags);
        if self.compression == Some(1) {
            return Ok(bytes.to_vec());
        }
        self.decoder
            .as_mut()
            .context("MOBI decoder was not configured")?
            .decode(bytes)
    }

    pub fn read_mobi_stream(&mut self, ranges: Vec<ByteRange>) -> Result<Vec<u8>> {
        let mut output = Vec::new();
        for range in ranges {
            output.extend_from_slice(&self.read_mobi_record(range)?);
        }
        Ok(output)
    }
}

pub fn read_file(path: String) -> Result<Vec<u8>> {
    let mut source = NativeFile::open(path)?;
    source.read_at(ByteRange {
        offset: 0,
        length: source.length,
    })
}

pub fn read_file_range(path: String, range: ByteRange) -> Result<Vec<u8>> {
    NativeFile::open(path)?.read_at(range)
}

fn strip_trailing(mut bytes: &[u8], flags: u32) -> &[u8] {
    for _ in 0..(flags >> 1).count_ones() {
        let mut length = 0usize;
        for &byte in &bytes[bytes.len().saturating_sub(4)..] {
            if byte & 0x80 != 0 {
                length = 0;
            }
            length = (length << 7) | usize::from(byte & 0x7f);
        }
        bytes = &bytes[..bytes.len().saturating_sub(length)];
    }
    if flags & 1 != 0
        && let Some(last) = bytes.last()
    {
        bytes = &bytes[..bytes.len().saturating_sub(usize::from(last & 3) + 1)];
    }
    bytes
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn trailing_zero_size_keeps_the_record() {
        assert_eq!(strip_trailing(&[1, 2, 0x80], 2), &[1, 2, 0x80]);
        assert_eq!(strip_trailing(&[1, 2, 0x83], 2), &[]);
        assert_eq!(strip_trailing(&[1, 2, 0], 1), &[1, 2]);
        assert_eq!(strip_trailing(&[], 3), &[]);
    }
}
