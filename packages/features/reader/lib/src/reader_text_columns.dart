import 'package:preferences_service/preferences_service.dart';

/// Longest text line in any window, in ems of the body text: about 68
/// characters, inside the 45–75 range typographers recommend for one column.
/// Phone pages in portrait are narrower, so it shapes landscape phones and
/// tablets.
const double kReaderMaxLineWidthEm = 32;

/// Text columns per page (`0` lets foliate choose) and the longest line in
/// ems, as `FoliateStyle` sends them.
typedef ReaderTextColumns = ({int maxColumnCount, double? maxLineWidthEm});

/// One column across the page: image pages, which keep their own layout.
const ReaderTextColumns kReaderFullWidthColumn = (
  maxColumnCount: 1,
  maxLineWidthEm: null,
);

/// What the reader asks foliate for in one window.
///
/// Text keeps the measure in every window. Only a wide window gets the
/// reader's [columns] choice; the Appearance row that sets it shows only
/// there, so a narrow window keeps one column whatever was chosen on a
/// tablet. [columns] is `null` for articles, which scroll as one column.
/// Image pages ([fixedLayout]) keep their own layout.
ReaderTextColumns readerTextColumns({
  required bool wideWindow,
  required bool fixedLayout,
  required ReaderColumns? columns,
}) {
  if (fixedLayout) return kReaderFullWidthColumn;
  return (
    maxColumnCount: switch (wideWindow ? columns : null) {
      null || ReaderColumns.one => 1,
      ReaderColumns.auto => 0,
      ReaderColumns.two => 2,
    },
    maxLineWidthEm: kReaderMaxLineWidthEm,
  );
}
