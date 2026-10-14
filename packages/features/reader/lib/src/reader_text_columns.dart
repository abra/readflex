import 'package:preferences_service/preferences_service.dart';

/// Longest text line in a wide window, in ems of the body text: about 68
/// characters, inside the 45–75 range typographers recommend for one column.
const double kReaderMaxLineWidthEm = 32;

/// Text columns per page (`0` lets foliate choose) and the longest line in
/// ems, as `FoliateStyle` sends them.
typedef ReaderTextColumns = ({int maxColumnCount, double? maxLineWidthEm});

/// One column across the page: narrow windows, phones included, and image
/// pages.
const ReaderTextColumns kReaderFullWidthColumn = (
  maxColumnCount: 1,
  maxLineWidthEm: null,
);

/// What the reader asks foliate for in one window.
///
/// Only a wide window gets a measure and the reader's [columns] choice; the
/// Appearance row that sets it shows only there, so a narrow window ignores
/// a choice made on a tablet. [columns] is `null` for articles, which scroll
/// as one column. Image pages ([fixedLayout]) keep their own layout.
ReaderTextColumns readerTextColumns({
  required bool wideWindow,
  required bool fixedLayout,
  required ReaderColumns? columns,
}) {
  if (!wideWindow || fixedLayout) return kReaderFullWidthColumn;
  return (
    maxColumnCount: switch (columns) {
      null || ReaderColumns.one => 1,
      ReaderColumns.auto => 0,
      ReaderColumns.two => 2,
    },
    maxLineWidthEm: kReaderMaxLineWidthEm,
  );
}
