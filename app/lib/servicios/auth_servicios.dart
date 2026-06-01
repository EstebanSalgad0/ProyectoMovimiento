class AuthServicio {
  static String usuarioActual = '';

  static bool login(String usuario, String contrasena) {
    const usuarios = {
      'admin': '1234',
      'usuario.prueba': '1234',
    };
    if (usuarios[usuario] == contrasena) {
      usuarioActual = usuario;
      return true;
    }
    return false;
    // Hice esto para no hardcodear datos y poder
    // Hacer un inicio de sesión basica sin levantar una bbdd xd
    // Retorna un "Token"
  }
  static void logout() {
    usuarioActual = '';
  }
}