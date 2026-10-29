pub use crate::archive::{ArchiveEntry, NativeArchive, read_zip_detached};
pub use crate::file::{ByteRange, NativeFile, read_file};
pub use crate::markup::{NativeDocument, parse_html, parse_xml, parse_xml_async};

use flutter_rust_bridge::frb;

#[frb(sync)]
pub fn is_release_build() -> bool {
    !cfg!(debug_assertions)
}
