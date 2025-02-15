#!/bin/sh

# Get the initial version.
perl version.pl

die() {
    echo "$@"
    exit 1
}

# Try to locate a program by using which, and verify that the file is an
# executable
locate_binary() {
  for f in $@
  do
    file=`which $f 2>/dev/null | grep -v '^no '`
    if test -n "$file" -a -x "$file"; then
      echo $file
      return 0
    fi
  done

  echo ""
  return 1
}

echo "aclocal..."
if test x$ACLOCAL = x; then
  ACLOCAL=`locate_binary aclocal`
  if test x$ACLOCAL = x; then
    die "Did not find a supported aclocal"
  fi
fi
$ACLOCAL || exit 1

echo "autoheader..."
AUTOHEADER=${AUTOHEADER:-autoheader}
$AUTOHEADER || exit 1

echo "automake..."
if test x$AUTOMAKE = x; then
  AUTOMAKE=`locate_binary automake`
  if test x$AUTOMAKE = x; then
    die "Did not find a supported automake"
  fi
fi
$AUTOMAKE --foreign --add-missing || $AUTOMAKE --gnu --add-missing || exit 1

echo "autoconf..."
AUTOCONF=${AUTOCONF:-autoconf}
$AUTOCONF || exit 1

