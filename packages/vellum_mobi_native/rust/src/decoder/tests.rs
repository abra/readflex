use super::*;

fn write_u32(bytes: &mut [u8], offset: usize, value: u32) {
    bytes[offset..offset + 4].copy_from_slice(&value.to_be_bytes());
}

fn dictionary(entries: &[(bool, &[u8])]) -> Vec<Vec<u8>> {
    let mut huff = vec![0; 24 + 256 * 4 + 32 * 8];
    huff[..4].copy_from_slice(b"HUFF");
    write_u32(&mut huff, 8, 24);
    write_u32(&mut huff, 12, 24 + 256 * 4);
    for i in 0..256 {
        write_u32(&mut huff, 24 + i * 4, (255 << 8) | 0x80 | 8);
    }
    let mut cdic = vec![0; 16 + entries.len() * 2];
    cdic[..4].copy_from_slice(b"CDIC");
    write_u32(&mut cdic, 4, 16);
    write_u32(&mut cdic, 8, entries.len() as u32);
    write_u32(&mut cdic, 12, 8);
    for (i, (decoded, bytes)) in entries.iter().enumerate() {
        let offset = (cdic.len() - 16) as u16;
        cdic[16 + i * 2..18 + i * 2].copy_from_slice(&offset.to_be_bytes());
        let word = bytes.len() as u16 | if *decoded { 0x8000 } else { 0 };
        cdic.extend_from_slice(&word.to_be_bytes());
        cdic.extend_from_slice(bytes);
    }
    vec![huff, cdic]
}

#[test]
fn palmdoc_literals_spaces_and_zero() {
    assert_eq!(
        decode_palmdoc(&[0, 3, 1, 2, 255, b'A', 0xc2]),
        [0, 1, 2, 255, b'A', b' ', b'B']
    );
    assert!(decode_palmdoc(&[]).is_empty());
}

#[test]
fn palmdoc_overlapping_and_invalid_backreferences() {
    assert_eq!(decode_palmdoc(&[b'a', 0x80, 0x0f]), b"aaaaaaaaaaa");
    assert_eq!(decode_palmdoc(&[0x80, 0x08]), [0, 0, 0]);
    assert_eq!(decode_palmdoc(&[0x80, 0x00]), [0, 0, 0]);
}

#[test]
fn palmdoc_truncation_matches_dart() {
    assert_eq!(decode_palmdoc(&[8, 1, 2]), [1, 2]);
    assert_eq!(decode_palmdoc(&[b'a', 0x80]), b"a");
}

#[test]
fn huff_literals_and_lazy_dictionary_cache() -> Result<()> {
    let records = dictionary(&[(false, &[254, 254]), (true, b"word ")]);
    let mut decoder = HuffDecoder::load(&records)?;
    assert_eq!(decoder.decode(&[255, 254], 0)?, b"word word word ");
    assert!(decoder.dictionary[0].state == EntryState::Decoded);
    let cached = decoder.cached_bytes;
    assert_eq!(decoder.decode(&[255], 0)?, b"word word ");
    assert_eq!(decoder.cached_bytes, cached);
    assert!(decoder.decode(&[], 0)?.is_empty());
    Ok(())
}

#[test]
fn huff_long_codes_and_zero_padded_tail() -> Result<()> {
    let mut records = dictionary(&[(true, b"a"), (true, b"b")]);
    for i in 0..256 {
        write_u32(&mut records[0], 24 + i * 4, 8);
    }
    let ranges = 24 + 256 * 4;
    write_u32(&mut records[0], ranges + 7 * 8, 256);
    write_u32(&mut records[0], ranges + 8 * 8 + 4, 511);
    let mut decoder = HuffDecoder::load(&records)?;
    assert_eq!(decoder.decode(&[0xff, 0xff, 0x80], 0)?, b"ab");
    Ok(())
}

#[test]
fn huff_dictionary_spanning_cdic_records() -> Result<()> {
    let mut records = dictionary(&[(true, b"a")]);
    write_u32(&mut records[1], 8, 2);
    write_u32(&mut records[1], 12, 0);
    let mut second = dictionary(&[(true, b"b")]).remove(1);
    write_u32(&mut second, 8, 2);
    records.push(second);
    assert_eq!(HuffDecoder::load(&records)?.decode(&[255, 254], 0)?, b"ab");
    Ok(())
}

#[test]
fn huff_cycles_fail_and_leave_session_usable() -> Result<()> {
    let records = dictionary(&[(false, &[255]), (true, b"ok")]);
    let mut decoder = HuffDecoder::load(&records)?;
    assert!(decoder.decode(&[255], 0).is_err());
    assert!(decoder.decode(&[255], 0).is_err());
    assert_eq!(decoder.decode(&[254], 0)?, b"ok");
    Ok(())
}

#[test]
fn huff_malformed_dictionaries_return_errors() {
    let records = dictionary(&[(true, b"a")]);
    for index in 0..records.len() {
        for length in 0..records[index].len() {
            let mut truncated = records.clone();
            truncated[index].truncate(length);
            assert!(
                HuffDecoder::load(&truncated).is_err(),
                "record {index}, length {length}"
            );
        }
    }
    let mut invalid = records.clone();
    write_u32(&mut invalid[0], 24, 0);
    assert!(
        HuffDecoder::load(&invalid)
            .unwrap()
            .decode(&[0], 0)
            .is_err()
    );
    let mut invalid = records.clone();
    write_u32(&mut invalid[1], 12, 64);
    assert!(HuffDecoder::load(&invalid).is_err());
    let mut invalid = records.clone();
    write_u32(&mut invalid[0], 8, u32::MAX);
    assert!(HuffDecoder::load(&invalid).is_err());
    assert!(Decoder::load(1, &[]).is_err());
}

#[test]
fn huff_invalid_symbols_and_lengths_return_errors() -> Result<()> {
    let mut records = dictionary(&[(true, b"a")]);
    assert!(HuffDecoder::load(&records)?.decode(&[0], 0).is_err());
    for i in 0..256 {
        write_u32(&mut records[0], 24 + i * 4, 31);
    }
    let ranges = 24 + 256 * 4;
    write_u32(&mut records[0], ranges + 30 * 8, u32::MAX);
    write_u32(&mut records[0], ranges + 31 * 8, u32::MAX);
    assert!(HuffDecoder::load(&records)?.decode(&[0; 8], 0).is_err());
    Ok(())
}

#[test]
fn huff_nesting_and_expansion_limits() -> Result<()> {
    let packed: Vec<_> = (0..130).map(|i| vec![(254 - i) as u8]).collect();
    let mut entries: Vec<_> = packed
        .iter()
        .map(|bytes| (false, bytes.as_slice()))
        .collect();
    entries.push((true, b"end"));
    assert!(
        HuffDecoder::load(&dictionary(&entries))?
            .decode(&[255], 0)
            .is_err()
    );

    let packed: Vec<_> = (0..28).map(|i| vec![(254 - i) as u8; 2]).collect();
    let mut entries: Vec<_> = packed
        .iter()
        .map(|bytes| (false, bytes.as_slice()))
        .collect();
    entries.push((true, b"x"));
    assert!(
        HuffDecoder::load(&dictionary(&entries))?
            .decode(&[255], 0)
            .is_err()
    );
    Ok(())
}
