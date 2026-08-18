//! The lock's `installedAt` instant, validated but not computed.
//!
//! The crate is clockless (like `grimoire-pack`, which takes timestamps from
//! its callers), so an instant arrives from outside. It arrives as a validated
//! newtype rather than a `time::OffsetDateTime` to keep the dependency floor
//! at zero: the only shape we accept is the one `install.sh` writes,
//! `date -u +%Y-%m-%dT%H:%M:%SZ`, so parity needs no date arithmetic.

use crate::{CoreError, Result};

/// An RFC3339 UTC instant in exactly `YYYY-MM-DDTHH:MM:SSZ` form.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct Timestamp(String);

impl Timestamp {
    /// Validate lexically: exact shape, ASCII digits, and each field in range.
    /// Deliberately *not* a full RFC3339 parser — offsets, fractional seconds
    /// and two-digit years are rejected, because writing anything but the
    /// canonical shape into the lock would diverge from the shell reference
    /// implementation.
    pub fn parse(s: &str) -> Result<Self> {
        let bad = || CoreError::Timestamp(s.to_string());
        let b = s.as_bytes();
        if b.len() != 20 {
            return Err(bad());
        }
        if !(b[4] == b'-' && b[7] == b'-' && b[10] == b'T' && b[13] == b':' && b[16] == b':' && b[19] == b'Z')
        {
            return Err(bad());
        }
        let field = |range: std::ops::Range<usize>| -> Option<u32> {
            let part = s.get(range)?;
            if !part.bytes().all(|c| c.is_ascii_digit()) {
                return None;
            }
            part.parse().ok()
        };
        let month = field(5..7).ok_or_else(bad)?;
        let day = field(8..10).ok_or_else(bad)?;
        let hour = field(11..13).ok_or_else(bad)?;
        let minute = field(14..16).ok_or_else(bad)?;
        let second = field(17..19).ok_or_else(bad)?;
        field(0..4).ok_or_else(bad)?; // year: shape only, any 4 digits
        if !(1..=12).contains(&month)
            || !(1..=31).contains(&day)
            || hour > 23
            || minute > 59
            || second > 60
        // 60 tolerated: a leap second is a legal `date -u` output
        {
            return Err(bad());
        }
        Ok(Self(s.to_string()))
    }

    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_the_shape_install_sh_writes() {
        let t = Timestamp::parse("2026-08-18T12:34:56Z").unwrap();
        assert_eq!(t.as_str(), "2026-08-18T12:34:56Z");
        // the boundaries of each field
        assert!(Timestamp::parse("2026-01-01T00:00:00Z").is_ok());
        assert!(Timestamp::parse("2026-12-31T23:59:60Z").is_ok());
    }

    #[test]
    fn rejects_everything_that_is_not_that_shape() {
        for bad in [
            "2026-08-18 12:34:56Z",      // space instead of T
            "2026-08-18T12:34:56",       // no zone
            "2026-08-18T12:34:56+01:00", // offset, not UTC
            "2026-13-01T00:00:00Z",      // month 13
            "2026-08-32T00:00:00Z",      // day 32
            "2026-08-18T24:00:00Z",      // hour 24
            "2026-08-18T12:60:00Z",      // minute 60
            "26-08-18T12:34:56Z",        // two-digit year
            "2026-08-18T12:34:56.7Z",    // fractional seconds
            "20x6-08-18T12:34:56Z",      // non-digit
            "",
        ] {
            assert!(
                Timestamp::parse(bad).is_err(),
                "should have rejected {bad:?}"
            );
        }
    }
}
