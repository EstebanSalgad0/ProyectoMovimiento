/// Formatos en español (Chile) sin depender de la configuración regional.
class Formato {
  static const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  static const _diasCortos = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  static String _dos(int n) => n.toString().padLeft(2, '0');
  static String hora(DateTime f) => '${_dos(f.hour)}:${_dos(f.minute)}';
  static String mesCorto(int mes) => _meses[mes - 1].substring(0, 3);
  static String diaSemanaCorto(DateTime f) => _diasCortos[f.weekday - 1];
  static String inicialDia(DateTime f) => _diasCortos[f.weekday - 1][0].toUpperCase();

  static int _diasDesde(DateTime f, DateTime ahora) =>
      DateTime(ahora.year, ahora.month, ahora.day).difference(DateTime(f.year, f.month, f.day)).inDays;

  /// "Hoy, 14:05" · "Ayer, 09:12" · "lun 3 oct, 18:20"
  static String fechaRelativa(DateTime f, {DateTime? ahora}) {
    final a = ahora ?? DateTime.now();
    final d = _diasDesde(f, a);
    if (d == 0) return 'Hoy, ${hora(f)}';
    if (d == 1) return 'Ayer, ${hora(f)}';
    final base = '${diaSemanaCorto(f)} ${f.day} ${mesCorto(f.month)}';
    return f.year == a.year ? '$base, ${hora(f)}' : '$base ${f.year}';
  }

  /// "lunes 6 de octubre de 2026, 14:05"
  static String fechaLarga(DateTime f) =>
      '${_dias[f.weekday - 1]} ${f.day} de ${_meses[f.month - 1]} de ${f.year}, ${hora(f)}';

  static String grupoFecha(DateTime f, {DateTime? ahora}) {
    final a = ahora ?? DateTime.now();
    final d = _diasDesde(f, a);
    if (d <= 0) return 'Hoy';
    if (d == 1) return 'Ayer';
    if (d < 7) return 'Esta semana';
    if (f.year == a.year && f.month == a.month) return 'Este mes';
    return '${_meses[f.month - 1][0].toUpperCase()}${_meses[f.month - 1].substring(1)} ${f.year}';
  }

  static String saludo([DateTime? ahora]) {
    final h = (ahora ?? DateTime.now()).hour;
    if (h < 12) return 'Buenos días';
    if (h < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }

  /// Número con coma decimal: 1,5
  static String numero(double valor, [int decimales = 1]) {
    final texto = valor.toStringAsFixed(decimales);
    return decimales == 0 ? texto : texto.replaceAll('.', ',');
  }

  static String segundos(double s) =>
      s < 60 ? '${numero(s, s < 10 ? 1 : 0)} s' : '${s ~/ 60}:${_dos((s % 60).round())} min';

  static String cronometro(Duration d) => '${_dos(d.inMinutes)}:${_dos(d.inSeconds % 60)}';

  static String tamanoArchivo(int bytes) {
    if (bytes < 1024 * 1024) return '${numero(bytes / 1024, 0)} KB';
    return '${numero(bytes / (1024 * 1024))} MB';
  }

  static String plural(int n, String singular, String plural) => '$n ${n == 1 ? singular : plural}';
}
