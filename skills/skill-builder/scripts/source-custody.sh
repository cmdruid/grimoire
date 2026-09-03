#!/usr/bin/env bash
set -u

reason(){ printf 'reason=%s\n' "$1" >&2; exit 2; }
usage(){ reason usage; }
physical_dir(){ [ -d "$1" ] || return 1; (CDPATH='' cd -P -- "$1" 2>/dev/null && pwd -P); }
contained(){ case "$1/" in "$2/"*) return 0;; *) return 1;; esac; }
valid_slug(){ case "$1" in ''|*[!a-z0-9-]*|-*|*-) return 1;; *) return 0;; esac; }

[ "$#" -eq 2 ] && [ "$1" = inspect ] || usage
source_arg="$2"
case "$source_arg" in *'
'*) reason invalid-source;; esac

git_top="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
candidate="$source_arg"
case "$candidate" in /*) ;; *) candidate="$PWD/$candidate";; esac

package=""
if [ -e "$candidate" ] || [ -L "$candidate" ]; then
  if [ -d "$candidate" ]; then
    package="$(physical_dir "$candidate")" || reason invalid-source
  elif [ "$(basename -- "$candidate")" = SKILL.md ] && [ -f "$candidate" ] && [ ! -L "$candidate" ]; then
    package="$(physical_dir "$(dirname -- "$candidate")")" || reason invalid-source
  else
    reason invalid-source
  fi
elif valid_slug "$source_arg" && [ -n "$git_top" ]; then
  slug_candidate="$git_top/skills/$source_arg"
  package="$(physical_dir "$slug_candidate")" || reason invalid-source
else
  reason invalid-source
fi

if valid_slug "$source_arg" && [ -n "$git_top" ]; then
  slug_package="$(physical_dir "$git_top/skills/$source_arg" 2>/dev/null || true)"
  if [ -n "$slug_package" ] && [ "$slug_package" != "$package" ]; then
    reason ambiguous-source
  fi
fi

case "$package" in *'
'*) reason invalid-source;; esac
manifest="$package/SKILL.md"
[ -f "$manifest" ] && [ ! -L "$manifest" ] || reason invalid-manifest

declared_name="$(awk '
  /^---[[:space:]]*$/ { block++; next }
  block == 1 && /^name:[[:space:]]*/ {
    sub(/^name:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit
  }
' "$manifest")"
[ -n "$declared_name" ] || reason invalid-manifest
directory_name="$(basename -- "$package")"
name_matches=no
if valid_slug "$declared_name" && [ "$declared_name" = "$directory_name" ]; then
  name_matches=yes
fi

git_root="$(git -C "$package" rev-parse --show-toplevel 2>/dev/null || true)"
head=absent tracked=no
if [ -n "$git_root" ]; then
  git_root="$(physical_dir "$git_root")" || git_root=""
fi
if [ -n "$git_root" ] && contained "$package" "$git_root"; then
  head="$(git -C "$git_root" rev-parse --verify HEAD 2>/dev/null || printf absent)"
  rel="${package#"$git_root"/}"
  [ "$package" = "$git_root" ] && rel=""
  tracked_path="${rel:+$rel/}SKILL.md"
  git -C "$git_root" ls-files --error-unmatch -- "$tracked_path" >/dev/null 2>&1 && tracked=yes
else
  git_root=absent
fi

immutable=unknown
manager=""
if [ -n "${GRIMOIRE_HOME:-}" ] && [ "${GRIMOIRE_HOME#/}" != "$GRIMOIRE_HOME" ]; then
  manager="$GRIMOIRE_HOME"
elif [ -n "${HOME:-}" ] && [ "${HOME#/}" != "$HOME" ]; then
  manager="$HOME/.grimoire"
fi
if [ -n "$manager" ]; then
  if [ ! -e "$manager" ] && [ ! -L "$manager" ]; then
    immutable=no
  elif [ -d "$manager" ]; then
    manager_real="$(physical_dir "$manager" 2>/dev/null || true)"
    if [ -z "$manager_real" ] || [ -L "$manager/store" ] || [ -L "$manager/store/checkouts" ]; then
      immutable=unknown
    elif [ ! -e "$manager_real/store/checkouts" ]; then
      immutable=no
    elif [ -d "$manager_real/store/checkouts" ]; then
      store_real="$(physical_dir "$manager_real/store/checkouts" 2>/dev/null || true)"
      if [ -z "$store_real" ]; then
        immutable=unknown
      elif contained "$package" "$store_real"; then
        immutable=yes
      else
        immutable=no
      fi
    fi
  fi
fi

command -v perl >/dev/null 2>&1 || reason sha256-unavailable
package_sha256="$(LC_ALL=C perl -MDigest::SHA -MFile::Find -MFcntl=:mode -e '
  use strict; use warnings; use bytes;
  my $root = shift @ARGV;
  my @entries;
  my $walked = eval {
    local $SIG{__WARN__} = sub { die "traversal-warning\n"; };
    find({ no_chdir => 1, follow => 0, wanted => sub {
      my $path = $File::Find::name;
      return if $path eq $root;
      my $rel = substr($path, length($root) + 1);
      if ($rel =~ m{(?:^|/)\.git(?:/|$)}) {
        $File::Find::prune = 1 if -d _;
        return;
      }
      push @entries, $rel;
    }}, $root);
    1;
  };
  if (!$walked) { print STDERR "reason=unreadable-entry\n"; exit 2; }
  @entries = sort { $a cmp $b } @entries;
  my $sha = Digest::SHA->new(256);
  sub frame { my ($value) = @_; $sha->add(pack("Q>", length($value)), $value); }
  for my $rel (@entries) {
    my $path = "$root/$rel";
    my @st = lstat($path);
    if (!@st) { print STDERR "reason=unreadable-entry\n"; exit 2; }
    my ($type, $exec, $payload) = ("", "0", "");
    if (S_ISREG($st[2])) {
      $type = "file"; $exec = ($st[2] & 0111) ? "1" : "0";
      open my $fh, "<:raw", $path or do { print STDERR "reason=unreadable-entry\n"; exit 2; };
      local $/; $payload = <$fh>; $payload = "" unless defined $payload; close $fh;
    } elsif (S_ISDIR($st[2])) {
      $type = "dir";
    } elsif (S_ISLNK($st[2])) {
      $type = "link"; $payload = readlink($path);
      if (!defined $payload) { print STDERR "reason=unreadable-entry\n"; exit 2; }
    } else {
      print STDERR "reason=unsupported-entry\n"; exit 2;
    }
    frame($rel); frame($type); frame($exec); frame($payload);
  }
  print $sha->hexdigest;
' "$package")" || exit $?

custodied=no
if [ "$name_matches" = yes ] && [ "$tracked" = yes ] && [ "$immutable" = no ] && [ "$git_root" != absent ] && [ "$head" != absent ]; then
  custodied=yes
fi

printf 'physical-package-root=%s\n' "$package"
printf 'declared-name=%s\n' "$declared_name"
printf 'name-matches-directory=%s\n' "$name_matches"
printf 'git-root=%s\n' "$git_root"
printf 'head=%s\n' "$head"
printf 'tracked=%s\n' "$tracked"
printf 'immutable=%s\n' "$immutable"
printf 'custodied=%s\n' "$custodied"
printf 'package-sha256=%s\n' "$package_sha256"
