const ui = @import("../ui.zig");
const geom = @import("../geometry.zig");
const v = geom.Vec;

const Element = ui.Element;

/// Fill entire available space
pub fn size_fill(_: *Element, bounds: geom.AABB) geom.AABB {
    return bounds;
}

/// Size is preset
pub fn size_static(el: *Element, _: geom.AABB) geom.AABB {
    return el.size;
}

/// No layout
pub fn layout_relative(el: *Element, _: usize) geom.AABB {
    return el.size;
}

/// Divide vertical space equally
pub fn layout_div_vertical(el: *Element, childID: usize) geom.AABB {
    const vsize = @divTrunc(el.size.size[v.y], @intCast(i32, el.children));
    return geom.AABB.initv(
        el.size.pos + geom.Vec2{ 0, @intCast(i32, childID) * vsize },
        geom.Vec2{ el.size.size[v.x], vsize },
    );
}

/// Divide horizontal space equally
pub fn layout_div_horizontal(el: *Element, childID: usize) geom.AABB {
    const hsize = @divTrunc(el.size.size[v.x], @intCast(i32, el.children));
    return geom.AABB.initv(
        el.size.pos + geom.Vec2{ @intCast(i32, childID) * hsize, 0 },
        geom.Vec2{ hsize, el.size.size[v.y] },
    );
}

/// Center component
pub fn layout_center(el: *Element, childID: usize) geom.AABB {
    const centerv = el.size.pos + @divTrunc(el.size.size, geom.Vec2{ 2, 2 });
    var centeraabb = geom.AABB.initv(centerv, geom.Vec2{ 0, 0 });
    if (el.getChild(childID)) |child| {
        centeraabb.pos -= @divTrunc(child.size.size, geom.Vec2{ 2, 2 });
        centeraabb.size = child.size.size;
    }
    return centeraabb;
}
