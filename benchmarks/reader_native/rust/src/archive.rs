#![forbid(unsafe_code)]

use std::collections::HashMap;
use std::io::Read;

use anyhow::{Context, Result, bail, ensure};
use flate2::read::DeflateDecoder;
use flutter_rust_bridge::frb;

use crate::file::{ByteRange, NativeFile};

#[derive(Clone, Debug)]
pub struct ArchiveEntry {
    pub name: String,
    pub method: u16,
    pub compressed_size: u64,
    pub uncompressed_size: u64,
    pub local_header_offset: u64,
    pub crc32: u32,
    pub encrypted: bool,
}

#[frb(opaque)]
pub struct NativeArchive {
    file: NativeFile,
    entries: Vec<ArchiveEntry>,
    offsets: HashMap<u64, usize>,
}

impl NativeArchive {
    pub fn open(path: String) -> Result<Self> {
        let mut file = NativeFile::open(path)?;
        let entries = read_directory(&mut file)?;
        let offsets = entries
            .iter()
            .enumerate()
            .map(|(i, e)| (e.local_header_offset, i))
            .collect();
        Ok(Self {
            file,
            entries,
            offsets,
        })
    }

    pub fn entries(&self) -> Vec<ArchiveEntry> {
        self.entries.clone()
    }

    pub fn read_entry(&mut self, offset: u64, max_bytes: u64) -> Result<Vec<u8>> {
        let &index = self.offsets.get(&offset).context("Unknown archive entry")?;
        read_entry(&mut self.file, &self.entries[index], max_bytes)
    }
}

pub fn read_zip_detached(path: String, entry: ArchiveEntry, max_bytes: u64) -> Result<Vec<u8>> {
    read_entry(&mut NativeFile::open(path)?, &entry, max_bytes)
}

fn read_entry(file: &mut NativeFile, entry: &ArchiveEntry, max: u64) -> Result<Vec<u8>> {
    ensure!(!entry.encrypted, "Encrypted ZIP entry");
    ensure!(matches!(entry.method, 0 | 8), "Unsupported ZIP compression");
    let limit = max;
    ensure!(
        entry.uncompressed_size <= limit,
        "ZIP entry exceeds read limit"
    );
    let header = file.read_at(ByteRange {
        offset: entry.local_header_offset,
        length: 30,
    })?;
    ensure!(
        u32_at(&header, 0)? == 0x04034b50,
        "Damaged ZIP local header"
    );
    let offset = entry
        .local_header_offset
        .checked_add(30 + u64::from(u16_at(&header, 26)?) + u64::from(u16_at(&header, 28)?))
        .context("ZIP offset overflow")?;
    let packed = file.read_at(ByteRange {
        offset,
        length: entry.compressed_size,
    })?;
    ensure!(
        packed.len() as u64 == entry.compressed_size,
        "Truncated ZIP entry"
    );
    let output = if entry.method == 0 {
        packed
    } else {
        let mut output = Vec::new();
        DeflateDecoder::new(packed.as_slice())
            .take(limit.saturating_add(1))
            .read_to_end(&mut output)?;
        output
    };
    ensure!(
        output.len() as u64 <= limit,
        "Inflated ZIP entry exceeds limit"
    );
    ensure!(
        output.len() as u64 == entry.uncompressed_size,
        "ZIP entry size mismatch"
    );
    Ok(output)
}

fn read_directory(file: &mut NativeFile) -> Result<Vec<ArchiveEntry>> {
    let length = file.length();
    let tail_length = length.min(65557);
    let tail = file.read_at(ByteRange {
        offset: length - tail_length,
        length: tail_length,
    })?;
    let eocd = (0..tail.len().saturating_sub(21))
        .rev()
        .find(|&i| {
            u32_at(&tail, i).ok() == Some(0x06054b50)
                && u16_at(&tail, i + 20).is_ok_and(|n| i + 22 + usize::from(n) == tail.len())
        })
        .context("Not a ZIP archive")?;
    let mut count = u64::from(u16_at(&tail, eocd + 10)?);
    let mut size = u64::from(u32_at(&tail, eocd + 12)?);
    let mut offset = u64::from(u32_at(&tail, eocd + 16)?);
    if count == 0xffff || size == 0xffffffff || offset == 0xffffffff {
        let locator = eocd.checked_sub(20).context("Missing ZIP64 locator")?;
        ensure!(
            u32_at(&tail, locator)? == 0x07064b50,
            "Damaged ZIP64 locator"
        );
        let record = file.read_at(ByteRange {
            offset: u64_at(&tail, locator + 8)?,
            length: 56,
        })?;
        ensure!(
            u32_at(&record, 0)? == 0x06064b50,
            "Damaged ZIP64 end record"
        );
        count = u64_at(&record, 32)?;
        size = u64_at(&record, 40)?;
        offset = u64_at(&record, 48)?;
    }
    ensure!(
        size <= 64 * 1024 * 1024 && offset.checked_add(size).is_some_and(|end| end <= length),
        "Damaged ZIP directory"
    );
    let bytes = file.read_at(ByteRange {
        offset,
        length: size,
    })?;
    let mut cursor = 0usize;
    let mut entries = Vec::new();
    for _ in 0..count {
        ensure!(
            u32_at(&bytes, cursor)? == 0x02014b50,
            "Damaged ZIP directory entry"
        );
        let flags = u16_at(&bytes, cursor + 8)?;
        let method = u16_at(&bytes, cursor + 10)?;
        let crc32 = u32_at(&bytes, cursor + 16)?;
        let mut packed = u64::from(u32_at(&bytes, cursor + 20)?);
        let mut plain = u64::from(u32_at(&bytes, cursor + 24)?);
        let name_len = usize::from(u16_at(&bytes, cursor + 28)?);
        let extra_len = usize::from(u16_at(&bytes, cursor + 30)?);
        let comment_len = usize::from(u16_at(&bytes, cursor + 32)?);
        let mut local = u64::from(u32_at(&bytes, cursor + 42)?);
        let name_start = cursor + 46;
        let extra_start = name_start + name_len;
        let end = extra_start + extra_len + comment_len;
        let raw_name = bytes
            .get(name_start..extra_start)
            .context("Truncated ZIP entry name")?;
        ensure!(end <= bytes.len(), "Truncated ZIP directory entry");
        let mut extra = extra_start;
        while extra + 4 <= extra_start + extra_len {
            let id = u16_at(&bytes, extra)?;
            let length = usize::from(u16_at(&bytes, extra + 2)?);
            if id == 1 {
                let mut field = extra + 4;
                if plain == 0xffffffff {
                    plain = u64_at(&bytes, field)?;
                    field += 8;
                }
                if packed == 0xffffffff {
                    packed = u64_at(&bytes, field)?;
                    field += 8;
                }
                if local == 0xffffffff {
                    local = u64_at(&bytes, field)?;
                }
                break;
            }
            extra += 4 + length;
        }
        let name = match std::str::from_utf8(raw_name) {
            Ok(name) => name.to_owned(),
            Err(_) if flags & 0x800 == 0 => decode_cp437(raw_name),
            Err(_) => bail!("Invalid UTF-8 ZIP entry name"),
        };
        entries.push(ArchiveEntry {
            name,
            method,
            compressed_size: packed,
            uncompressed_size: plain,
            local_header_offset: local,
            crc32,
            encrypted: flags & 1 != 0,
        });
        cursor = end;
    }
    Ok(entries)
}

fn u16_at(bytes: &[u8], offset: usize) -> Result<u16> {
    let value = bytes
        .get(offset..offset.checked_add(2).context("ZIP integer overflow")?)
        .context("Truncated ZIP integer")?;
    Ok(u16::from_le_bytes([value[0], value[1]]))
}

fn u32_at(bytes: &[u8], offset: usize) -> Result<u32> {
    let value = bytes
        .get(offset..offset.checked_add(4).context("ZIP integer overflow")?)
        .context("Truncated ZIP integer")?;
    Ok(u32::from_le_bytes(value.try_into()?))
}

fn u64_at(bytes: &[u8], offset: usize) -> Result<u64> {
    let value = bytes
        .get(offset..offset.checked_add(8).context("ZIP integer overflow")?)
        .context("Truncated ZIP integer")?;
    Ok(u64::from_le_bytes(value.try_into()?))
}

fn decode_cp437(bytes: &[u8]) -> String {
    const HIGH: &str = "ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒáíóúñÑªº¿⌐¬½¼¡«»░▒▓│┤╡╢╖╕╣║╗╝╜╛┐└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■ ";
    let high: Vec<_> = HIGH.chars().collect();
    bytes
        .iter()
        .map(|&b| {
            if b < 128 {
                char::from(b)
            } else {
                high[usize::from(b) - 128]
            }
        })
        .collect()
}
