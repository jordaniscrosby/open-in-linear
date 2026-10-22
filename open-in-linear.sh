#!/bin/zsh
# Open in Linear: selected text -> Linear issue (if it's an ID) or Linear search.
# Reads the selection on stdin. Set DRY_RUN=1 to print the URL instead of opening it.

workspace="your-workspace"   # install.sh fills this in

text="$(head -c 4096 | iconv -c -f UTF-8 -t UTF-8 | tr '\r\n\t' '   ' | sed -E 's/^ +//; s/ +$//; s/ +/ /g')"
[[ -z "$text" ]] && exit 0

id_re='[A-Za-z][A-Za-z0-9]{1,9}-[0-9]+'
id=""

if [[ "$text" =~ ^${id_re}$ ]]; then
  # Exactly an ID: ENG-123, eng-123
  id="$text"
elif [[ "$text" =~ linear\.app/[^/]+/issue/(${id_re}) ]]; then
  # A Linear issue URL
  id="${match[1]}"
elif [[ "$text" != *" "* && "$text" =~ (^|[/_])(${id_re})(-|$) ]]; then
  # A single token with an ID in it, like a branch name: you/eng-123-fix-the-thing
  id="${match[2]}"
fi

if [[ -n "$id" ]]; then
  url="https://linear.app/${workspace}/issue/${id:u}"
else
  q=$(V="$text" osascript -l JavaScript -e 'ObjC.import("stdlib"); function run(){return encodeURIComponent($.getenv("V"))}')
  url="https://linear.app/${workspace}/search?q=${q}&includeArchived=true"
fi

if [[ -n "$DRY_RUN" ]]; then
  print -r -- "$url"
else
  open -a Linear "$url" 2>/dev/null || open "$url"
fi
