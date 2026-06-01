import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTipo {
  static TextStyle appName()      => GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700);
  static TextStyle sectionTitle() => GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600);
  static TextStyle cardTitle()    => GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600);
  static TextStyle body()         => GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400);
  static TextStyle bodyMedium()   => GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500);
  static TextStyle label()        => GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400);
  static TextStyle labelMedium()  => GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500);
  static TextStyle caption()      => GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400);
  static TextStyle captionCaps()  => GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.66);
  static TextStyle badge()        => GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600);
  static TextStyle statNumber()   => GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700);
}