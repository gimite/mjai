window.console ||= {}
window.console.log ||= ->
window.console.error ||= ->

window.Dytem =
  
  init: ->
    Dytem.addChildrenField($("body"), null, Dytem)
  
  assign: (obj, elem) ->
    #console.log("assign", obj, elem)
    elem ||= Dytem
    if typeof(obj) == "string"
      elem.text(obj)
    else if obj instanceof Array
      elem.clear()
      for childObj in obj
        childElem = elem.append()
        Dytem.assign(childObj, childElem)
    else
      for name, childObj of obj
        if name == "text"
          elem.text(childObj)
        else if name == "html"
          elem.html(childObj)
        else if elem[name]
          Dytem.assign(childObj, elem[name])
        else if elem.attr
          elem.attr(name, childObj)
        else
          throw("unknown field: #{name}")
  
  addChildrenField: (elem, prefix, target) ->
    elem.find("[id]").each (i, child) =>
      childId = $(child).attr("id")
      $(child).removeAttr("id") if prefix
      escPrefix = if prefix then prefix.replace(/\./, "\\.") else ""
      if childId.match(new RegExp("^#{escPrefix}([^\\.]+)$"))
        name = RegExp.$1
        if $(child).hasClass("repeated")
          target[name] = new Repeated(childId, $(child))
        else
          target[name] = $(child)

class Repeated
  
  constructor: (@__id, @__placeholder) ->
    # Doesn't use selector because @__id may contain ".".
    @__template = $(document.getElementById(@__id))
    @__elems = []
  
  append: ->
    if @__elems.length > 0
      lastElem = @__elems[@__elems.length - 1]
    else
      lastElem = @__placeholder
    newElem = @__template.clone()
    newElem.removeAttr("id")
    Dytem.addChildrenField(newElem, "#{@__id}.", newElem)
    newElem.show()
    lastElem.after(newElem)
    @__elems.push(newElem)
    return newElem
  
  at: (idx) ->
    return @__elems[idx]
  
  size: ->
    return @__elems.length
  
  resize: (n) ->
    if n < @__elems.length
      for elem in @__elems[n...]
        elem.remove()
      @__elems[n...] = []
    else if n > @__elems.length
      for i in [@__elems.length...n]
        @append()
  
  clear: ->
    for elem in @__elems
      elem.remove()
    @__elems = []
