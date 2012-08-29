
# Form: a thing that is visible once drawn.

require("backend.jl")
require("queue.jl")
require("property.jl")
require("measure.jl")

# A bare form.
abstract FormType

# A container for one or more forms with applied properties.
type Form <: FormType
    property::Property
    specifics::Vector{FormType}

    function Form()
        new(Property(),
            FormType[])
    end

    function Form(property::Property, specifics::Vector{FormType})
        new(property, specifics)
    end
end


# Package a Form with the information needed to draw it.
type DrawFormContext
    form::FormType
    parent_property::Property
end


# Draw a form and all it contains on a backend within a bounding box.
function draw(backend::Backend, t::NativeTransform,
              unit_box::BoundingBox, box::NativeBoundingBox,
              root_property::Property, root_form::Form)
    Q = Queue()
    enqueue(Q,
        DrawFormContext(root_form,
                        root_property))

    while !isempty(Q)
        ctx = pop(Q)

        # if form is not a Form, it is not a container so we can draw in
        # directly
        if typeof(ctx.form) != Form
            draw(backend, t, unit_box, box, ctx.parent_property)
            draw(backend, t, unit_box, box, ctx.form)
        else
            if isempty(ctx.form.property)
                property = ctx.parent_property
            else
                property = copy(ctx.parent_property)
                append!(property.specifics, ctx.form.property.specifics)
            end

            for f in ctx.form.specifics
                enqueue(Q, DrawFormContext(f, property))
            end
        end
    end
end


# Each form translates into a series of lower-level drawing operations.
abstract DrawOp


# By default, Assume no coordinate conversion is needed.
function draw(backend::Backend, t::NativeTransform, unit_box::BoundingBox,
              box::NativeBoundingBox, op::DrawOp)
    draw(backend, op)
end


type MoveTo <: DrawOp
    point::Point
end


function draw(backend::Backend, t::NativeTransform, unit_box::BoundingBox,
              box::NativeBoundingBox, op::MoveTo)
    draw(backend, MoveTo(native_measure(op.point, t, unit_box, box, backend)))
end


type LineTo <: DrawOp
    point::Point
end


function draw(backend::Backend, t::NativeTransform, unit_box::BoundingBox,
              box::NativeBoundingBox, op::LineTo)
    draw(backend, LineTo(native_measure(op.point, t, unit_box, box, backend)))
end


type FillStroke <: DrawOp end
type ClosePath  <: DrawOp end


# Specific forms

# Note that the constructors for these types are somewhat peculiar: they return
# an instance of the type they construct wrapped in a Form.


type Lines <: FormType
    points::Vector{Point}

    function Lines(points::XYTupleOrPoint...)
        Form(Property(),
             FormType[new([convert(Point, point) for point in points])])
    end
end


function draw(backend::Backend, t::NativeTransform, unit_box::BoundingBox,
              box::NativeBoundingBox, form::Lines)
    if isempty(form.points); return; end

    draw(backend, t, unit_box, box, MoveTo(form.points[1]))
    for point in form.points[2:]
        draw(backend, t, unit_box, box, LineTo(point))
    end
    draw(backend, t, unit_box, box, FillStroke())
end


type Polygon <: FormType
    points::Vector{Point}

    function Polygon(points::XYTupleOrPoint...)
        Form(Property(),
             FormType[new([convert(Point, point) for point in points])])
    end
end


function draw(backend::Backend, t::NativeTransform, unit_box::BoundingBox,
              box::NativeBoundingBox, form::Polygon)
    if isempty(form.points); return; end

    draw(backend, t, unit_box, box, MoveTo(form.points[1]))
    for point in form.points[2:]
        draw(backend, t, unit_box, box, LineTo(point))
    end
    draw(backend, t, unit_box, box, ClosePath())
    draw(backend, t, unit_box, box, FillStroke())
end


type Rectangle <: FormType
    xy0::Point
    xy1::Point

    function Rectangle(x0::MeasureOrNumber, y0::MeasureOrNumber,
                       width::MeasureOrNumber, height::MeasureOrNumber)
        Form(Property(),
             FormType[new(Point(x0, y0), Point(x0 + width, y0 + height))])
    end

    function Rectangle()
        Rectangle(0.0, 0.0, 1.0, 1.0)
    end
end


function draw(backend::Backend, t::NativeTransform, unit_box::BoundingBox,
              box::NativeBoundingBox, form::Rectangle)
    draw(backend, t, unit_box, box, MoveTo(form.xy0))
    draw(backend, t, unit_box, box, LineTo(Point(form.xy1.x, form.xy0.y)))
    draw(backend, t, unit_box, box, LineTo(Point(form.xy1.x, form.xy1.y)))
    draw(backend, t, unit_box, box, LineTo(Point(form.xy0.x, form.xy1.y)))
    draw(backend, t, unit_box, box, ClosePath())
    draw(backend, t, unit_box, box, FillStroke())
end
