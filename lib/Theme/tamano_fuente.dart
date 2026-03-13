enum FontSizeOption { small, medium, large }

extension FontSizeExtension on FontSizeOption {
  double get baseSize {
    switch (this) {
      case FontSizeOption.small:
        return 12.0;
      case FontSizeOption.medium:
        return 16.0;
      case FontSizeOption.large:
        return 20.0;
    }
  }

  String get label {
    switch (this) {
      case FontSizeOption.small:
        return 'Pequeño';
      case FontSizeOption.medium:
        return 'Mediano';
      case FontSizeOption.large:
        return 'Grande';
    }
  }
}
