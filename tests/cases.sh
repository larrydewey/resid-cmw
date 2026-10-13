# The test transcript: every command below runs in a scratch directory $W
# with $CMW the built tool, and run.sh compares what it prints (stdout,
# stderr and the exit status) with tests/cases.out. Inputs are made here,
# from printf or from the tool itself, so the suite needs no CBOR library.

t() { # t <command...>: run it and record its output and status
    echo "\$ $*" | sed "s#$W/##g; s#$CMW#resid-cmw#g"
    "$@" 2>&1 | sed "s#$W/##g"
    echo "[exit ${PIPESTATUS[0]}]"
}
hex() { # hex <file> <hex>: write bytes
    printf '%s' "${*:2}" | tr -d ' ' | xxd -r -p > "$W/$1"
}

printf 'hello' > "$W/hello.bin"
printf '\x01\x02\x03' > "$W/three.bin"
: > "$W/empty.bin"

echo "## building"
t $CMW wrap application/eat+cbor "$W/hello.bin" --ind evidence -o "$W/ev.cmw"
t $CMW wrap application/octet-stream "$W/three.bin" -o "$W/raw.cmw"
t $CMW wrap application/octet-stream "$W/empty.bin" --ind 'endorsements,reference-values' -o "$W/empty.cmw"
t $CMW wrap text/plain "$W/hello.bin" --ind 4294967295 -o "$W/allbits.cmw"
t $CMW collect --type tag:example.com,2026:demo ev=$W/ev.cmw raw=$W/raw.cmw -o "$W/inner.cmw"
t $CMW collect outer=$W/inner.cmw z=$W/raw.cmw e=$W/empty.cmw -o "$W/tree.cmw"
t $CMW collect all=$W/allbits.cmw -o "$W/allbits-coll.cmw"
echo "## bytes are deterministic"
t xxd -p "$W/ev.cmw"
t xxd -p "$W/tree.cmw"

echo "## reading"
t $CMW inspect "$W/tree.cmw"
t $CMW inspect "$W/tree.cmw" --values
t $CMW inspect "$W/allbits-coll.cmw"
t $CMW diag "$W/tree.cmw"
t $CMW check "$W/ev.cmw" "$W/tree.cmw"

echo "## extracting"
t $CMW extract "$W/tree.cmw" outer/ev --value
t $CMW extract "$W/tree.cmw" /outer/ev -o "$W/ev2.cmw"
t cmp "$W/ev.cmw" "$W/ev2.cmw"
t $CMW extract "$W/tree.cmw" / -o "$W/tree2.cmw"
t cmp "$W/tree.cmw" "$W/tree2.cmw"
t $CMW extract "$W/tree.cmw" outer --value
t $CMW extract "$W/tree.cmw" z/q
t $CMW extract "$W/tree.cmw" nope
t $CMW extract "$W/tree.cmw" outer/nope

echo "## editing"
t $CMW set "$W/tree.cmw" outer/added "$W/raw.cmw" -o "$W/set.cmw"
t $CMW inspect "$W/set.cmw"
t $CMW set "$W/tree.cmw" z "$W/ev.cmw" -o "$W/replaced.cmw"
t $CMW inspect "$W/replaced.cmw"
t $CMW set "$W/tree.cmw" missing/x "$W/raw.cmw" -o "$W/x.cmw"
t $CMW set "$W/tree.cmw" / "$W/raw.cmw" -o "$W/x.cmw"
t $CMW set "$W/tree.cmw" __cmwc_t "$W/raw.cmw" -o "$W/x.cmw"
t $CMW remove "$W/tree.cmw" outer/raw -o "$W/removed.cmw"
t $CMW inspect "$W/removed.cmw"
t $CMW remove "$W/removed.cmw" outer/ev -o "$W/x.cmw"
t $CMW remove "$W/tree.cmw" outer/zzz -o "$W/x.cmw"
t ls "$W/x.cmw"

echo "## refused builds"
t $CMW wrap "" "$W/hello.bin" -o "$W/x.cmw"
t $CMW wrap "$(printf 'a\tb')" "$W/hello.bin" -o "$W/x.cmw"
t $CMW wrap t "$W/hello.bin" --ind bogus -o "$W/x.cmw"
t $CMW wrap t "$W/hello.bin" --ind 4294967296 -o "$W/x.cmw"
t $CMW wrap t "$W/nonexistent" -o "$W/x.cmw"
t $CMW collect a=$W/raw.cmw a=$W/ev.cmw -o "$W/x.cmw"
t $CMW collect __cmwc_t=$W/raw.cmw -o "$W/x.cmw"
t $CMW collect noequals -o "$W/x.cmw"
t $CMW collect =$W/raw.cmw -o "$W/x.cmw"
t $CMW collect a=$W/hello.bin -o "$W/x.cmw"
t $CMW collect --type "" a=$W/raw.cmw -o "$W/x.cmw"
t ls "$W/x.cmw"

echo "## nesting limit"
cp "$W/raw.cmw" "$W/d1.cmw"
for i in 2 3 4 5 6 7 8 9 10 11 12; do
    $CMW collect "l$i=$W/d$((i - 1)).cmw" -o "$W/d$i.cmw"
done
t $CMW check "$W/d12.cmw"
t $CMW collect "l13=$W/d12.cmw" -o "$W/d13.cmw"
t $CMW set "$W/d12.cmw" l12/x "$W/d2.cmw" -o "$W/d13.cmw"
t $CMW set "$W/d12.cmw" l12/x "$W/raw.cmw" -o "$W/d12b.cmw"
t $CMW check "$W/d12b.cmw"
hex d13.cmw a1616ca1616ca1616ca1616ca1616ca1616ca1616ca1616ca1616ca1616ca1616ca1616c8261614100
t $CMW check "$W/d13.cmw"

echo "## refused inputs"
hex intlabel.cmw   a1018261614100
hex fourelem.cmw   84616141000102
hex bigind.cmw     8361614100 1b0000000100000000
hex textvalue.cmw  8261616162
hex intmedia.cmw   82014100
hex indef.cmw      9f61614100ff
hex trailing.cmw   8261614100 00
hex emptymap.cmw   a0
hex duplabel.cmw   a26178826161410061788261614100
hex badtype.cmw    a1685f5f636d77635f74 01
hex scalar.cmw     01
hex truncated.cmw  826161
hex ctrlmedia.cmw  8261074100
hex onlytype.cmw   a1685f5f636d77635f746161
: > "$W/zero.cmw"
for f in intlabel fourelem bigind textvalue intmedia indef trailing emptymap duplabel badtype scalar truncated ctrlmedia onlytype zero; do
    t $CMW check "$W/$f.cmw"
done
t $CMW check "$W/raw.cmw" "$W/scalar.cmw" "$W/ev.cmw"
t $CMW inspect "$W/nonexistent"
mkdir -p "$W/adir"
t $CMW inspect "$W/adir"
t $CMW inspect -

echo "## usage"
t $CMW
t $CMW --version
t $CMW frobnicate
t $CMW inspect
t $CMW inspect "$W/raw.cmw" --bogus
t $CMW wrap t "$W/hello.bin"
t $CMW wrap t "$W/hello.bin" -o
t $CMW extract "$W/raw.cmw" -- --value
