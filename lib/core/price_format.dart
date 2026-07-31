String won(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$out원';
}

String checkedDate(DateTime value) => '${value.month}월 ${value.day}일 확인';
