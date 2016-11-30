local classes = {}

function new(name)
    return function(...)
        if classes[name].constructor then --Has a constructor
            classes[name].constructor(classes[name], ...)
        end

        return classes[name]
    end
end

function class(name)
    return function(cTable)
        classes[name] = setmetatable(cTable, {__index = classes[cName]})

        if classes[name][1] then --Is derived from a class
            setmetatable(classes[name], {
                __index = classes[classes[name][1]];
            })

            classes[name].parentConstructor = classes[classes[name][1]].constructor;
        end
    end
end
