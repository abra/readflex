#![forbid(unsafe_code)]

use anyhow::Result;
use flutter_rust_bridge::frb;

use crate::decoder::Decoder;

/// Owns the HUFF dictionary and its lazy expansion cache for one book session.
#[frb(opaque)]
pub struct MobiDecoder {
    decoder: Decoder,
}

impl MobiDecoder {
    pub fn new(compression: u16, dictionary_records: Vec<Vec<u8>>) -> Result<Self> {
        Ok(Self {
            decoder: Decoder::load(compression, &dictionary_records)?,
        })
    }

    /// FRB runs this synchronous Rust method on its pool, with asynchronous Dart.
    /// The mutable opaque borrow serializes calls that share a dictionary cache.
    pub fn decode_batch(&mut self, records: Vec<Vec<u8>>) -> Result<Vec<Vec<u8>>> {
        records
            .iter()
            .map(|record| self.decoder.decode(record))
            .collect()
    }
}

#[frb(sync)]
pub fn is_release_build() -> bool {
    !cfg!(debug_assertions)
}
