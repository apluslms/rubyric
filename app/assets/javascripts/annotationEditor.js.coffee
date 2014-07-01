#= require jquery.ui.draggable
#= require jquery.ui.droppable
#= require reviewEditor
#= require editable

ko.bindingHandlers.onload = {
  init: (element, valueAccessor, bindingHandlers, viewModel) ->
    callback = ko.utils.unwrapObservable(valueAccessor())
    
    $(element).bind 'load', ->
      callback.call(viewModel)
}

# Custom KnockOut binding for the jQuery UI draggable
ko.bindingHandlers.draggable = {
  init: (element, valueAccessor, allBindingsAccessor, viewModel) ->
    startCallback = valueAccessor().start
    stopCallback = valueAccessor().stop

    dragOptions = {
      distance: 5
      cursor: 'default'
      cursorAt: { left: 40, top: 5 }
      zIndex: 100
      appendTo: "body"
      helper: -> $('<div class="annotation-drag-helper"></div>')
    }

    dragOptions['start'] = (-> startCallback.call(viewModel)) if startCallback
    dragOptions['stop'] = (-> stopCallback.call(viewModel)) if stopCallback

    $(element).draggable(dragOptions).disableSelection()
    
}


# Custom KnockOut binding for the jQuery UI droppable
ko.bindingHandlers.droppable = {
  init: (element, valueAccessor, allBindingsAccessor, viewModel) ->
    dropCallback = valueAccessor().drop
    
    dropOptions = {
      tolerance: 'touch'
      accept: 'tr.phrase'
      drop: (event, ui) ->
        dragObject = ko.dataFor(ui.draggable.get(0))
        dropCallback(viewModel, dragObject, event, ui)
    }

    $(element).droppable(dropOptions)
}


# Custom KnockOut binding that makes it possible to move DOM objects.
# Usage:
# data-bind="position: position"
# @position = ko.observable({x: 0, y: 0})
#
# pos = @position()
# pos.x = 10
# pos.updated = false
# @position.valueHasMutated()
ko.bindingHandlers.position = {
  init: (element, valueAccessor, bindingHandlers, viewModel) ->
#     pos = $(element).position()
#     value = ko.utils.unwrapObservable(valueAccessor())
#     value.x = pos.left if value.x?
#     value.y = pos.top if value.y?
#     value.width = pos.width if value.width?
#     value.height = pos.height if value.height?

    dragOptions = {
      #containment: 'parent'
      distance: 5
      cursor: 'default'
    }

    #dragOptions['start'] = (-> startCallback.call(viewModel)) if startCallback
    dragOptions['stop'] = ->
      # Update model after drag and notify observers
      pos = $(element).position()
      value = ko.utils.unwrapObservable(valueAccessor())
      value.x = pos.left
      value.y = pos.top
      valueAccessor().valueHasMutated()
      
      # stopCallback.call(viewModel)) if stopCallback

    el = $(element)
    el.draggable(dragOptions)
    # el.disableSelection()  # This is commented out because it would be impossible to select text in the text area
    

  update: (element, valueAccessor, bindingHandlers, viewModel) ->
    value = ko.utils.unwrapObservable(valueAccessor())

    # Return if DOM is already up to date.
    # (Knockout calls update of all bindings if one binding changes which would
    # cause unwanted position updates for example, during a drag.)
    return if value['updated']
    
    el = $(element)
    options = {}
    options['left'] = value.x if value.x?
    options['top'] = value.y if value.y?
    options['width'] = value.width if value.width?
    options['height'] = value.height if value.height?

    el.css(options)
    #el.animate(options, 150)
    
    value['updated'] = true
}

class SetSelectedPhraseCommand
  constructor: (@phrase) ->
    # TODO: @previous_phrase = ...
    
    @phrase.criterion.setSelectedPhrase(phrase) if phrase.grade?
    
  undo: ->
    # TODO
    
  as_json: ->
    {
      command: 'set_selected_phrase'
      phrase_id: @phrase.id
      criterion_id: @phrase.criterion.id
      page_id: @phrase.criterion.page.id
    }

class SetPageGradeCommand
  constructor: (@page, @grade) ->
    # TODO: @previous_grade = ...
  
  undo: ->
  
  as_json: ->
    {
      command: 'set_page_grade'
      page_id: @page.id
      grade: @grade
    }

class CreateAnnotationCommand
  constructor: (@page, options) ->
    @annotation = new Annotation(options)
    @page.annotations.push(@annotation)
    @annotation.contentEditorActive(true) if options['activateEditor']
  
  undo: ->
    @page.annotations.remove(@annotation)
  
  as_json: ->
    return if @annotation.deleted  # Deleted new Annotations can be ignored
    
    {
      command: 'create_annotation'
      submission_page_number: @annotation.submissionPage.pageNumber
      phrase_id: if @annotation.phrase then @annotation.phrase.id else undefined
      content: @annotation.content()
      grade: @annotation.grade()
      page_position: @annotation.pagePosition()
    }
  
class DeleteAnnotationCommand
  constructor: (@annotation) ->
    @annotation.submissionPage.annotations.remove(@annotation)
    @annotation.phrase.criterion.annotations.remove(@annotation) if @annotation.phrase?
    @annotation.deleted = true
  
  undo: ->
    @annotation.submissionPage.annotations.push(@annotation)
    @annotation.deleted = false
  
  as_json: ->
    return unless @annotation.id?  # Deletions of new Annotations can be ignored
  
    {
      command: 'delete_annotation'
      id: @annotation.id
    }

class ModifyAnnotationCommand
  constructor: (@annotation, @change) ->
  
  undo: ->
  
  as_json: ->
    return if !@annotation.id? || @annotation.deleted   # Modifications to new Annotations can be ignored because the final values are saved anyway
    
    @change['command'] = 'modify_annotation'
    @change['id'] = @annotation.id
    return @change
    

class CommandBuffer
  constructor: ->
    @buffer = []
  
  as_json: ->
    array = []
    for command in @buffer
      json = command.as_json()
      array.push(json) if json
    
    return array


class SubmissionPage
  constructor: (@annotationEditor, @pageNumber) ->
    @src = ko.observable()
    @alt = ko.observable("Page #{@pageNumber + 1}")
    @nextPage = undefined
    @width = ko.observable()
    @containerWidth = ko.observable()
    @height = ko.observable()
    
    @annotations = ko.observableArray()
    
    @annotationEditor.zoom.subscribe =>
      this.updateZoom()
      #@src("#{@annotationEditor.submission_url}?page=#{@pageNumber}&zoom=#{@annotationEditor.zoom()}")  # FIXME: repetition
      this.loadPage()
    
    this.updateZoom()
  
  updateZoom: () ->
    new_zoom = @annotationEditor.zoom()
    pixelsPerCentimeter = 45.0 * new_zoom
    
    @width("#{Math.round(@annotationEditor.page_width * pixelsPerCentimeter)}px")
    @containerWidth("#{Math.round(@annotationEditor.page_width * pixelsPerCentimeter + 320)}px")
    @height("#{Math.round(@annotationEditor.page_height * pixelsPerCentimeter)}px")
    
    for annotation in @annotations()
      annotation.setZoom(new_zoom)
    
  
  loadPage: () ->
    url = "#{@annotationEditor.submission_url}?page=#{@pageNumber}&zoom=#{@annotationEditor.zoom()}"
    url += "&group_token=#{@annotationEditor.group_token}" if @annotationEditor.group_token && @annotationEditor.group_token.length > 0
    @src(url)
  
  # Called after image has been loaded
  onLoad: () ->
    # TODO: load when scrolling
    @nextPage.loadPage() if @nextPage

  clickCreateAnnotation: (submissionPage, event) =>
    currentTarget = event.currentTarget
    element = $('#submission-pages')
    scrollTop = element.scrollTop()
    scrollLeft = element.scrollLeft()

    options = {
      submissionPage: this
      content: ''
      grade: undefined
      screenPosition: {x: event.pageX - currentTarget.offsetLeft + scrollLeft, y: event.pageY - currentTarget.offsetTop + scrollTop}
      zoom: @annotationEditor.zoom()
      activateEditor: true
    }
    
    this.createAnnotation(options)
    
  
  createAnnotation: (options) ->
    command = new CreateAnnotationCommand(this, options)
    @annotationEditor.addCommand(command)
    @annotationEditor.subscribeToAnnotation(command.annotation)
    

  deleteAnnotation: (annotation, event) =>
    @annotationEditor.addCommand(new DeleteAnnotationCommand(annotation))
    event.preventDefault()
  
    
class Annotation
  constructor: (options) ->
    options ||= {}
    
    @id = options['id']
    @phrase = options['phrase']
    @submissionPage = options['submissionPage']
    @content = ko.observable(options['content'])
    @escaped_content = (options['content'] || '').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\n/g,'<br />')
    @grade = ko.observable(options['grade'])
    @zoom = options.zoom || 1.0
    
    screenPosition = options['screenPosition']
    pagePosition = options['pagePosition']
    
    # Calculate screenPos from pagePos or vice versa if only one is given
    pagePosition = {x: screenPosition.x / @zoom, y: screenPosition.y / @zoom} if !pagePosition && screenPosition
    screenPosition = {x: pagePosition.x * @zoom, y: pagePosition.y * @zoom} if !screenPosition && pagePosition
    
    @pagePosition = ko.observable(pagePosition || {x: 0, y: 0})
    @screenPosition = ko.observable(screenPosition || {x: 0, y: 0})
    
    @gradeEditorActive = ko.observable(false)
    @contentEditorActive = ko.observable(false)
    
    @phrase.criterion.annotations.push(this) if @phrase
    
    #console.log @phrase.criterion.grade
    #@phrase.criterion.grade.subscribe (new_value) =>
    #  console.log "Grade changed to #{new_value}"
  
    # Subscribe to screen position changes to update pagePos after dragging.
    @screenPosition.subscribe =>
      screenPos = @screenPosition()
      pagePos = @pagePosition()
      pagePos.x = screenPos.x / @zoom
      pagePos.y = screenPos.y / @zoom
      
      # TODO: limit x
      # if pagePos.x > @submissionPage.width()
      #   pagePos.x = @submissionPage.width()
      #   screenPos.x = pagePos.x * @zoom
      #   @screenPosition.valueHasMutated()
      
      @pagePosition.valueHasMutated()
    
  setZoom: (new_zoom) ->
    @zoom = new_zoom
    screenPos = @screenPosition()
    pagePos = @pagePosition()
    screenPos.updated = false
    screenPos.x = pagePos.x * @zoom
    screenPos.y = pagePos.y * @zoom
    @screenPosition.valueHasMutated()
  
  
  clickAnnotation: ->
    # Catch clicks and prevent bubbling


class AnnotationEditor extends Rubric
  constructor: () ->
    super()
    
    @element = $('#annotation-editor')
    @submission_url = @element.data('submission-url')
    @page_count = @element.data('page-count')
    @page_width = @element.data('page-width')
    @page_height = @element.data('page-height')
    @group_token = @element.data('group-token')
    initialPageId = @element.data('initial-rubric-page')
    initialZoom = @element.data('initial-zoom')
    
#     @zoom_options = [
#       {value: 0.25, text: "25 %"},
#       {value: 0.50, text: "50 %"},
#       {value: 0.75, text: "75 %"},
#       {value: 1.00, text: "100 %"},
#       {value: 1.25, text: "125 %"},
#       {value: 1.50, text: "150 %"},
#       {value: 1.75, text: "175 %"},
#       {value: 2.00, text: "200 %"}
#     ]
    
    if initialZoom
      zoom = parseInt(initialZoom) / 100.0
      zoom = 1.0 if isNaN(zoom)
      zoom = 0.25 if zoom < 0.25
      zoom = 2.0 if zoom > 2.0
    else
      zoom = 1.0
    
    @zoom_selection = ko.observable(zoom * 100)
    @zoom_selection.extend({ rateLimit: 1000 })
    @zoom = ko.observable(zoom)
    
    @submission_pages = ko.observableArray()
    @phrasesById = {}
    
    @commandBuffer = new CommandBuffer()
    
    this.createSubmissionPages()
    
    # reviewEditor features
    @saved = true
    @finalizing = ko.observable(false)
    
    @finalGrade = ko.observable()
    finalGrade = $('#review_grade').val()
    @finalGrade(finalGrade) if finalGrade && finalGrade != ''
    
    status = $('#review_status').val()
    @finalizing(true) if status && status.length > 0 && status != 'started'
    
    $('#tab-finish-link').tab('show') if @finalizing()
    
    this.parseRubric(window.rubric)
    
    for page in @pages
      do (page) =>
        page.grade.subscribe (new_grade) =>
          this.addCommand(new SetPageGradeCommand(page, new_grade))

    this.parseReview(window.review)
    
    ko.applyBindings(this)
    
    # Select initial rubric page
    initialPage = @pagesById[parseInt(initialPageId)] if initialPageId
    if initialPage
      initialPage.showTab()
    else
      $('#tab-overview-link').tab('show')
      
    # Subscribe to zoom changes
    @zoom_selection.subscribe (new_value) =>
      new_zoom = parseInt(new_value) / 100.0
      new_zoom = 1.0 if isNaN(new_zoom)
      new_zoom = 0.25 if new_zoom < 0.25
      new_zoom = 2.0 if new_zoom > 2.0
      @zoom(new_zoom)
  
  createSubmissionPages: ->
    previousPage = undefined
    for i in [0...@page_count]
      page = new SubmissionPage(this, i)
      @submission_pages.push(page)
      
      previousPage.nextPage = page if previousPage
      previousPage = page
    
    @submission_pages()[0].loadPage() if @submission_pages().length > 0
  
  
  parseReview: (data) ->
    data ||= {}
    
    for raw_annotation in (data['annotations'] || [])
      submission_page = @submission_pages()[raw_annotation['submission_page_number']]
      continue unless submission_page
      phrase = @phrasesById[raw_annotation['phrase_id']]
    
      options = {
        'id': raw_annotation['id']
        'submissionPage': submission_page
        'phrase': phrase
        'content': raw_annotation['content']
        'grade': raw_annotation['grade']
        'pagePosition': raw_annotation['page_position']
      }
    
      annotation = new Annotation(options)
      submission_page.annotations().push(annotation)
      this.subscribeToAnnotation(annotation)
    
    for page_data in (data['pages'] || [])
      page = @pagesById[page_data['id']]
      page.load_review(page_data) if page
    
    for submission_page in @submission_pages()
      submission_page.annotations.valueHasMutated()
    
    if (@gradingMode == 'average' && @grades.length > 0)
      @averageGrade = ko.computed((-> 
        grades = []
        for page in @pages
          grades.push(page.grade())
        
        return this.calculateGrade(grades)
      ), this)
    else if @gradingMode == 'sum'
      @averageGrade = ko.computed((-> 
        grades = []
        for page in @pages
          grade = page.averageGrade()
          grades.push(grade) if grade?
        
        return this.calculateGrade(grades)
      ), this)
    else
      @averageGrade = ko.observable()
  
  
  addCommand: (command) ->
    @commandBuffer.buffer.push(command)
  
  
  subscribeToAnnotation: (annotation) ->
    # Subscribe to modifications
    annotation.content.subscribe (newValue) =>
      this.addCommand(new ModifyAnnotationCommand(annotation, {content: newValue}))
  
    annotation.grade.subscribe (newValue) =>
      this.addCommand(new ModifyAnnotationCommand(annotation, {grade: newValue}))
    
    annotation.pagePosition.subscribe (newValue) =>
      this.addCommand(new ModifyAnnotationCommand(annotation, {page_position: newValue}))
    
    
  cancelFinalize: ->
    @finalizing(false)
  
  
  showNextPage: (page) =>
    if page.nextPage
      page.nextPage.showTab()
    else
      this.finish()
      $('#tab-finish-link').tab('show')
    
    # TODO: scroll to top
    #window.scrollTo(0, 0)
  
  clickCancelFinalize: (data, event) =>
    @finalizing(false)
  
  finish: ->
    return if @finalizing()  # Ignore if already finalizing
    
    @finalizing(true)
    
    # Calculate grade
    grades = @pages.map (page) -> page.grade()
    grade = this.calculateGrade(grades)
    @finalGrade(grade)
  
  
  clickGrade: (phrase) =>
    unless @gradingMode == 'sum'
      this.addCommand(new SetSelectedPhraseCommand(phrase))
      @saved = false
  
  
  clickPhrase: (phrase) =>
    # TODO: add annotation
    this.clickGrade(phrase)
  
  
  dropPhrase: (page, phrase, event, ui) =>
    return if @finalizing()
  
    offset = $(event.target).offset()
    
    options = {
      submissionPage: page
      phrase: phrase
      content: phrase.content
      grade: phrase.grade
      screenPosition: {x: ui.position.left - offset.left, y: ui.position.top - offset.top}
      zoom: @zoom()
    }
    
    page.createAnnotation(options)
    this.clickGrade(phrase)
  

  printJson: ->
    console.log @commandBuffer.as_json()

  # Populates the HTML-form from the model. This is called just before submitting.
  save: (options) ->
    options ||= {}
  
    # Encode review as JSON
    $('#review_payload').val(JSON.stringify(@commandBuffer.as_json()))
    
    # Set grade
    if @gradingMode == 'average'
      finalGrade = @finalGrade()
    else if @gradingMode == 'sum'
      finalGrade = @averageGrade()
    else
      finalGrade = undefined
    
    if finalGrade? && finalGrade != false
      $('#review_grade').val(finalGrade)
    else
      $('#review_grade').val('')
    
    # Set status
    if @finalizing()
      if @gradingMode == 'average' && @grades.length > 0 && !@finalGrade()?
        status = 'unfinished'
      else
        status = 'finished'
        
        $('#send_review').val('true') if options['send']?  # Send immediately?
    else
      status = 'started'
    
    $('#review_status').val(status)
    
    $('#zoom_preference').val(@zoom() * 100)
    #$('#rubric_page_preference').val('true')
    
    @saved = true
    
    return true
  
  saveAndSend: ->
    this.save({send: true})

jQuery ->
  new AnnotationEditor
