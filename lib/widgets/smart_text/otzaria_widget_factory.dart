import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:fwfh_svg/fwfh_svg.dart';
import 'package:fwfh_url_launcher/fwfh_url_launcher.dart';

/// WidgetFactory לכל HtmlWidget באפליקציה: SVG (מ-EPUB/Markdown) ופתיחת
/// קישור חיצוני כש-onTapUrl לא טיפל בו.
class OtzariaWidgetFactory extends WidgetFactory
    with SvgFactory, UrlLauncherFactory {}
