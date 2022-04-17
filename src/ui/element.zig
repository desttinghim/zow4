const std = @import("std");
const ui = @import("../ui.zig");
const w4 = @import("wasm4");
const geom = @import("../geometry.zig");
const Input = @import("../input.zig");
const v = geom.Vec;

const PaintStyle = ui.style.PaintStyle;
const Event = ui.Event;
const EventData = ui.EventData;
const ListenFn = ui.ListenFn;

pub const Element = struct {
    hidden: bool = false,
    hover: bool = false,
    clicked: u8 = 0,
    style: union(enum) { static: PaintStyle, rule: fn (Element, PaintStyle) PaintStyle } = .{ .static = .background },
    children: u8 = 0,
    self: *anyopaque,
    /// Space that the element takes up
    ctx: *ui.Stage,
    prev: ?*@This() = null,
    next: ?*@This() = null,
    parent: ?*@This() = null,
    child: ?*@This() = null,
    // Function Pointers
    sizeFn: SizeFn,
    layoutFn: LayoutFn,
    renderFn: ?RenderFn,
    size: geom.AABB,

    /// Passed self, bounding box, and returns a size
    const SizeFn = fn (*Element, geom.AABB) geom.AABB;
    /// Passed self number of children, and child number, returns bounds to be passed to size
    const LayoutFn = fn (*Element, usize) geom.AABB;
    /// Draws element to the screen
    const RenderFn = fn (Element, PaintStyle) PaintStyle;

    pub fn init(ctx: *ui.Stage, self: *anyopaque, sizeFn: SizeFn, layoutFn: LayoutFn, renderFn: ?RenderFn) @This() {
        return @This(){
            .ctx = ctx,
            .self = self,
            .size = geom.AABB.init(0, 0, 160, 160),
            .sizeFn = sizeFn,
            .layoutFn = layoutFn,
            .renderFn = renderFn,
        };
    }

    pub fn listen(this: *@This(), event: Event, callback: ListenFn) void {
        this.ctx.listen(this, event, callback);
    }

    pub fn unlisten(this: *@This(), event: Event, callback: ListenFn) void {
        this.ctx.unlisten(this, event, callback);
    }

    pub fn update(this: *@This()) void {
        if (!this.size.contains(Input.mousepos())) {
            if (this.hover) {
                this.ctx.dispatch(this, .MouseLeave);
                this.hover = false;
            }
        }
        this.clicked -|= 1;
        if (this.child) |child| child.update();
        if (this.next) |next| next.update();
    }

    pub fn find_top(this: *@This(), pos: geom.Vec2) ?*@This() {
        if (!this.size.contains(pos)) return null;
        var candidate: ?*@This() = this;
        var child_opt = this.child;
        while (child_opt) |child| : (child_opt = child.next) {
            if (child.hidden) continue;
            if (child.size.contains(pos))
                candidate = child.find_top(pos);
        }
        return candidate;
    }

    pub fn bubble_up(this: *@This(), ev: EventData) void {
        switch (ev) {
            .MouseMoved => if (!this.hover) {
                this.hover = true;
                this.ctx.dispatch(this, .MouseEnter);
            },
            else => {},
        }
        this.ctx.dispatch(this, ev);

        if (this.parent) |parent| {
            parent.bubble_up(ev);
        }
    }

    pub fn remove(this: *@This()) void {
        this.detach();
        if (this.child) |child| child.remove();
        this.ctx.unlisten_all(this);
        this.ctx.alloc.destroy(this.self);
    }

    pub fn detach(this: *@This()) void {
        var next_opt = this.next;
        if (this.next) |next| {
            if (next == this.prev) this.prev = null;
            next.prev = this.prev;
        }
        this.next = null;
        if (this.prev) |prev| {
            if (prev != this.next)
                prev.next = next_opt;
        }
        this.prev = null;
        if (this.parent) |parent| {
            if (parent.child == this) {
                parent.child = next_opt;
            }
            parent.children -= 1;
            this.parent = null;
        }
    }

    pub fn move_to_front(this: *@This()) void {
        var next_opt = this.next;
        var parent_opt = this.parent;
        if (next_opt == null) return;
        this.detach();
        parent_opt.?.appendChild(this);
    }

    pub fn compute_size(this: *@This(), bounds: geom.AABB) void {
        this.size = this.sizeFn(this, bounds);
    }

    pub fn layout(this: *@This()) void {
        var child_opt = this.child;
        var i: usize = 0;
        while (child_opt) |child| : (i += 1) {
            const bounds = this.layoutFn(this, i);
            child.compute_size(bounds);
            child.layout();
            child_opt = child.next;
        }
    }

    pub fn getChild(this: *@This(), num: usize) ?*@This() {
        var i: usize = 0;
        var child_opt = this.child;
        while (child_opt) |child| : (child_opt = child.next) {
            if (i == num) return child;
            i += 1;
        }
        return null;
    }

    pub fn appendChild(this: *@This(), el: *@This()) void {
        if (this == el) return;
        el.parent = this;
        this.children += 1;

        var child_opt = this.child;
        while (child_opt) |child| {
            if (child.next) |next| {
                child_opt = next;
            } else {
                child.next = el;
                el.prev = child;
                break; // prevent else block
            }
        } else {
            this.child = el;
        }
    }

    pub fn render(this: @This(), parent_style: PaintStyle) void {
        if (!this.hidden) {
            const style = if (this.renderFn) |rfn| rfn(this, parent_style) else parent_style;
            if (this.child) |child| child.render(style);
        }
        if (this.next) |next| next.render(parent_style);
    }
};
