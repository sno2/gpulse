fn invalid_infinite_loop() {
  loop { }     // Behavior: { }.  Invalid because it’s empty.
}
