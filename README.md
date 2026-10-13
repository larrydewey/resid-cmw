# resid-cmw

A command-line tool for RATS Conceptual Message Wrappers
([draft-ietf-rats-msg-wrap](https://datatracker.ietf.org/doc/draft-ietf-rats-msg-wrap/))
in their CBOR form, written in [Resid](https://github.com/larrydewey/resid).

A CMW wraps an attestation message (evidence, endorsements, reference
values or attestation results) with its media type, so a receiver knows
what it holds without guessing. A *record* is one message: the array
`[media-type, bytes]` or `[media-type, bytes, indicator]`. A *collection*
is a map from labels to CMWs, with an optional `"__cmwc_t"` entry that
names the collection's type. Collections can nest.

resid-cmw inspects, builds and edits CMWs. The CMW model and its strict
codec are in the Resid standard library (`lib/cmw.resid`). This repository
adds only the command line and its tests.

## Build

You need an installed Resid toolchain (`./install.sh` in the Resid
repository puts `residc` in `~/.resid/bin`).

```sh
./build.sh          # writes ./resid-cmw
tests/run.sh        # builds it and runs the golden-transcript suite
```

`RESIDC=/path/to/residc` selects a different compiler.

## Usage

```
resid-cmw inspect <cmw> [--values]          tree of records and collections
resid-cmw diag <cmw>                        CBOR diagnostic notation
resid-cmw check <cmw>...                    validate; exit 1 if any is not a CMW
resid-cmw wrap <media-type> <file> [--ind I] -o <out>
resid-cmw collect [--type T] <label>=<cmw>... -o <out>
resid-cmw extract <cmw> <path> [--value] [-o <out>]
resid-cmw set <cmw> <path> <member-cmw> -o <out>
resid-cmw remove <cmw> <path> -o <out>
```

A path is labels joined by `/`, and `""` or `/` names the root. A label
that itself contains `/` can't be reached by a path. `<out>` may be `-` for
stdout, and `extract` writes to stdout when it has no `-o`. Input always comes
from a file: reading stdin isn't supported.

An indicator (`--ind`) is a number, or bit names joined by `,`:
`reference-values` (1), `endorsements` (2), `evidence` (4),
`attestation-results` (8).

Exit status: 0 on success, 1 when an input is refused, 2 on a usage error.

### Example

```sh
$ resid-cmw wrap application/eat+cbor token.cbor --ind evidence -o ev.cmw
$ resid-cmw wrap application/pkix-cert vcek.der -o cert.cmw
$ resid-cmw collect --type tag:example.com,2026:bundle ev=ev.cmw cert=cert.cmw -o bundle.cmw
$ resid-cmw inspect bundle.cmw
collection type="tag:example.com,2026:bundle" 2 members
  "ev": record "application/eat+cbor" 1184 bytes ind=evidence
  "cert": record "application/pkix-cert" 1361 bytes
$ resid-cmw diag bundle.cmw          # values shortened here
{
  "ev": ["application/eat+cbor", h'd28443a10126...', 4],
  "cert": ["application/pkix-cert", h'30820551...'],
  "__cmwc_t": "tag:example.com,2026:bundle"
}
$ resid-cmw extract bundle.cmw cert --value -o vcek-again.der
$ resid-cmw remove bundle.cmw cert -o ev-only.cmw
```

The evidence envelopes made by Resid's attester (`lib/evidence.resid`) are
CMW collections, so the tool reads them as they are.

## What the tool accepts

The decoder is the standard library's and is strict, because CMWs come
from outside:

- The input must be at most 4 MiB, a single well-formed CBOR item, with
  definite lengths and nothing after it.
- A record has 2 or 3 elements: a text media type of 1 to 255 printable
  ASCII characters, a byte string value, and an optional indicator that fits
  in an unsigned 32-bit integer.
- A collection has 1 to 256 members. Labels are text and appear once,
  `"__cmwc_t"` is reserved for the type, and collections nest at most 12
  levels.

Every refusal names what was wrong. Output is deterministic: a
collection's entries are written in the RFC 8949 §4.2.1 order, whatever
order they were given in, so the same CMW always encodes to the same bytes.
The tool writes at most 11 levels of nesting, so everything it writes can
be read back.

## Spec changes

The draft is still moving. Because the wire format lives in
`lib/cmw.resid`, a revision of the draft is handled there, and this tool
picks it up on the next build. Only a change to what a CMW *is* (for
example, a new kind of node) needs changes here as well.

## Future work

The tool covers the CBOR serialization only. The rest of the draft, roughly
in order of usefulness:

- **JSON serialization.** CMWs also have a JSON form: records as
  `[media-type, base64url-value, indicator?]` and collections as JSON
  objects. This needs [resid-json](https://github.com/larrydewey/resid-json)
  as a package dependency, plus `--format json` on input and output and a
  `convert` command between the two forms.
- **CBOR tag form.** A record can also be a CBOR tag whose number is
  derived from a CoAP Content-Format ID, wrapping only the value bytes.
  `lib/cmw.resid` doesn't read or write this form today, and a media type
  given as a Content-Format number is refused. Supporting it needs a
  Content-Format registry table and changes to `lib/cmw.resid`.
- **Integer labels.** The draft allows unsigned integers as collection
  labels. `lib/cmw.resid` refuses them, and paths would need a way to tell a
  number from text.
- **Signed CMWs.** A CMW can be carried in COSE_Sign1 or a JWS. COSE
  signing and verification can build on Resid's `lib/cosesig.resid`. JWS
  would be new, though its algorithms are already in the standard library.
  This would add `sign` and `verify-signature` commands.
- **Other carriers.** CMWs can travel inside an X.509 extension or as the
  `cmw` claim of an EAT. Both need DER or EAT encoding on top of
  `lib/der.resid` and `lib/cbor.resid`.
- **Evidence verification.** Verifying the attestation evidence inside an
  envelope (`lib/verify/verifier.resid`) needs the verifier's challenge
  token, its export key and a trust set, so it fits a verifier deployment
  better than a format tool. A `verify` command would wrap
  `verify_evidence_replayable` for that setting.
- **stdin input.** Reading a CMW from a pipe needs a byte-oriented stdin
  read in the Resid runtime.

## License

MIT. See [LICENSE](LICENSE).
