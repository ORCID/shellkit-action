sk-xml-to-txt() {
  sk_help "Usage: cat xml | $FUNCNAME RecordTagName Field1 Field2 ...." "$@" && return
  local tag=$1; shift
  local fields=""; fields="$@" # zsh compatible
  cat - >/tmp/xmloutput.$$
  if ! grep -q '<' /tmp/xmloutput.$$ ;then
    echo "WARNING: non xml response detected"
    cat /tmp/xmloutput.$$
    rm /tmp/xmloutput.$$ 2>/dev/null
    return
  fi

  cat /tmp/xmloutput.$$ | xmllint --format - | perl -ne '
BEGIN {
  @recs = %rec= ();
  $tag = shift @ARGV;
  @fields = split(qq| |,shift @ARGV);
};
m|<$tag>| ... m|</$tag>| or next;
if (m|<$tag>|) { %rec = (); next; }
if (m|</$tag>|) { push(@recs,{%rec}); next; }
m|<(\w+)>([^<]+)| and $rec{$1} = $2;
END {
  for $r (@recs) {
    @_ = ();
    for $f (@fields) { push(@_,$r->{$f}); }
    print join(qq| |,@_).qq|\n| if @_;
  }
};
' "$tag" "$fields"
  rm /tmp/xmloutput.$$ 2>/dev/null
}

sk-xml-pretty(){
  sk-pack-install -b xmllint -p libxml2-utils
  xmllint --format "$@"
}

