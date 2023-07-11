fn invalid_infinite_loop() {
  loop {
    discard; // Behavior { Next }.
  }          // Invalid, behavior of the whole loop is { }.
}
