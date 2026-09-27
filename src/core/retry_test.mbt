///|
test "retry only with a short Retry-After on transient responses" {
  inspect(@core.retry_delay_ms(429, Some("1")) is Some(1000), content="true")
  inspect(@core.retry_delay_ms(503, Some(" 0 ")) is Some(0), content="true")
  inspect(@core.retry_delay_ms(502, Some("1")) is Some(1000), content="true")
  inspect(@core.retry_delay_ms(429, Some("2")) is None, content="true")
  inspect(@core.retry_delay_ms(429, None) is None, content="true")
  inspect(@core.retry_delay_ms(429, Some("invalid")) is None, content="true")
  inspect(@core.retry_delay_ms(429, Some("-1")) is None, content="true")
  inspect(@core.retry_delay_ms(400, Some("1")) is None, content="true")
  inspect(@core.retry_delay_ms(200, Some("1")) is None, content="true")
}
