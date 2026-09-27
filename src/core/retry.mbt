///|
/// A classification POST can be retried only for throttling or server errors
/// with an integer Retry-After of at most one second. None means fail now.
/// Attempts and the overall deadline are enforced by the I/O caller.
pub fn retry_delay_ms(status : Int, retry_after : String?) -> Int? {
  if status != 429 && (status < 500 || status > 599) {
    return None
  }
  let value = match retry_after {
    Some(value) => value.trim()
    None => return None
  }
  let seconds = @string.parse_int(value, base=10) catch { _ => return None }
  if seconds >= 0 && seconds <= 1 {
    Some(seconds * 1000)
  } else {
    None
  }
}
