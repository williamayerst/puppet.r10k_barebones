class profiles::default_linux {

notify { 'Linux':
    withpath => false,
    name     => "I'm a Linux Server!",
  }

