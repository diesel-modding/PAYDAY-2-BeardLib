local mlerp = math.lerp

function Easing._linear(a, b, t)
	return mlerp(a, b, t)
end