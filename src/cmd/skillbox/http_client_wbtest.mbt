///|
suberror OtherHttpTestError {
  ConnectionFailed
}

///|
test "only validated short Retry-After HTTP errors are retryable" {
  inspect(
    fatal_classifier_error(ClassifierHttpError::HttpStatus(429, Some(1000))),
    content="false",
  )
  inspect(
    fatal_classifier_error(ClassifierHttpError::HttpStatus(503, Some(0))),
    content="false",
  )
  inspect(
    fatal_classifier_error(ClassifierHttpError::HttpStatus(429, None)),
    content="true",
  )
  inspect(
    fatal_classifier_error(OtherHttpTestError::ConnectionFailed),
    content="true",
  )
}
