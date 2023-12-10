module collection;

import c = libc;
import core.lifetime: move, forward, emplace;
import std.algorithm.comparison: min, max;
import std.typecons: Tuple;

struct Box(T) {
    T *ptr;
    alias ptr this;
    this(Ts...)(auto ref Ts args) {
        _init(); emplace(ptr, forward!args);
    }
    this(ref inout Box rhs) {
        _init(); c.memcpy(ptr, rhs.ptr, T.sizeof);
    }
    ~this() { free(); }
    void _init() { ptr = cast(T*) c.malloc(T.sizeof); }
    void free() { if(ptr) c.free(ptr); }
}

struct Block(T, P = void) {
    T *data;
    size_t cap;
    // ctor
    this(size_t rsv) { reserve(rsv); }
    this(ref inout Block rhs) {
        reserve(rhs.cap);
        c.memcpy(data, rhs.data, rhs.cap*T.sizeof);
    }
    ~this() { free(); }
    // memory
    void reserve(size_t n) {
        if(n <= cap) return;
        const old = cap;
        cap = n;
        data = cast(T*) c.realloc(data, n*T.sizeof);
        c.memset(data+old, 0, T.sizeof*(n-old));
    }
    void reserve() {
        if(end() <= data + cap) return;
        reserve(max(2*cap, 1));
    }
    void free() { if(data) c.free(data); }
    size_t size() inout { return end() - beg(); }
    bool is_empty() inout { return !size(); }
    // index
    ref inout(T) at(size_t idx) inout { return *(beg() + idx); }
    ref inout(T) opIndex(size_t idx) inout { return at(idx); }
    // slice
    alias Range = Tuple!(size_t, size_t);
    Range opSlice(size_t _:0)(size_t a, size_t b) inout { return Range(a, b); }
    inout(T)[] opIndex() inout { return data[beg()-data..end()-data]; }
    inout(T)[] opIndex(Range rng) inout { return data[rng[0]..rng[1]]; }
    size_t opDollar() inout { return size(); }
    // iter impl
    inout(T)* begImpl() inout { return data; }
    inout(T)* endImpl() inout { return data + cap; }
    static template CRTP(U, Base, const char[] method) {
        static if(__traits(hasMember, U, method))
        alias type = U; else alias type = Base;
        inout(type)* cvt(scope return inout(Base)* p) {
            return cast(inout(type)*)p;
        }
    }
    inout(T*) beg() inout {
        alias cvt = CRTP!(P, typeof(this), "begImpl").cvt;
        return cvt(&this).begImpl();
    }
    inout(T*) end() inout {
        alias cvt = CRTP!(P, typeof(this), "endImpl").cvt;
        return cvt(&this).endImpl();
    }
    inout(T*) last() inout {
        alias cvt = CRTP!(P, typeof(this), "endImpl").cvt;
        return cvt(&this).endImpl() - 1;
    }
}

struct Vec(T, P = void) {
    inout(T)* endImpl() inout { return data + len; }
    static if(is(P == void)) alias Px = Vec!T; else alias Px = P;
    Block!(T, Px) blk;
    size_t len;
    alias blk this;
    this(size_t rsv) { blk.reserve(rsv); }
    this(ref inout Vec rhs) {
        len = rhs.len;
        blk.reserve(rhs.len);
        c.memcpy(data, rhs.data, rhs.len*T.sizeof);
    }
    void set_len(size_t len) { this.len = len; }
    void push_back(T v) { blk.reserve(); move(v, *end()); ++len; }
    void emplace_back(Ts...)(auto ref Ts args) {
        blk.reserve(); emplace(end(), forward!args); ++len;
    }
}

struct Stack(T) {
    Vec!T vec;
    alias vec this;
    @property size_t pos() inout { return vec.len; }
    void push(T v) { vec.push_back(move(v)); }
    ref inout(T) peek() inout { return *last(); }
    T pop() { auto v = move(*last()); --len; return move(v); }
}

struct Queue(T) {
    inout(T)* begImpl() inout { return data + pos; }
    inout(T)* endImpl() inout { return data + len; }
    Vec!(T, Queue!T) vec;
    size_t pos;
    alias vec this;
    void push(T v) {
        if(is_empty()) { pos = len = 0; }
        vec.push_back(move(v));
    }
    ref inout(T) peek() inout { return *beg(); }
    T pop() { auto v = move(*beg()); ++pos; return move(v); }
}
