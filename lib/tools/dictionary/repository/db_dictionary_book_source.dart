import 'package:otzaria/data/data_providers/book_database_resolver.dart';
import 'package:otzaria/data/data_providers/db_read_worker.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';

/// שולף את שורות התוכן של ספר-מילון מבסיס הנתונים לפי כותרת.
///
/// מחזיר רשימה ריקה אם הספר אינו קיים במסד הרשמי.
Future<List<String>> loadDictionaryBookLines(String title) async {
  final resolved = await BookDatabaseResolver.resolveBook(
    title: title,
    officialOnly: true,
  );
  if (resolved == null) return const <String>[];
  return DbReadWorker.lineContents(
    SqliteDataProvider.instance.dbPath,
    resolved.book.id,
  );
}
