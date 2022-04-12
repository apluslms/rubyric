#= require jquery.ui.sortable
#= require editable

# TODO
# editable: undefined value, then edit and cancel => value is set to "undefined" string
# reorder pages
# preview (grader)
# preview (mail)
# page weights
# cut'n'paste

class TextField
  constructor: (@rubricEditor, @owner, @language, hash) ->
    @text = ko.observable('')
    @editorActive = ko.observable(false)
    @language.textFields.push(this) if @language
    @owner.push(this)               if @owner
    hash[@language.id] = this      if hash && @language
    
    @editorActive.subscribe => @rubricEditor.saved = false if @rubricEditor
    @text.subscribe => @rubricEditor.saved = false if @rubricEditor
        
  activateEditor: ->
    @editorActive(true)
      
  deleteText: ->
    return unless @owner
    @owner.remove(this)
    
class GradingInstructions
  constructor: (@rubricEditor, data) ->
    @textFields = ko.observableArray()
    @textFieldsByLanguageId = {}
    
    this.load_json(data)  
    
  load_json: (data) ->
    if @rubricEditor.multilingual 
      @textFields([]) 
      for lang in @rubricEditor.languages()
        instructions = @textFieldsByLanguageId[lang.id] || new TextField(@rubricEditor, @textFields, lang, @textFieldsByLanguageId)
        instructions.text(data[lang.name()]) if data && data[lang.name()]
    else
      for lang in @rubricEditor.languages()
        instructions = @textFieldsByLanguageId[lang.id] || new TextField(@rubricEditor, @textFields, lang, @textFieldsByLanguageId)
        instructions.text(data) if data
    
  to_json: ->
    max_len = 0
    instructions = {}
    for textField in @textFields()
      max_len = textField.text().length if textField.text().length > max_len
      instructions[textField.language.name()] = textField.text()
    instructions = undefined if max_len == 0
    return instructions
    
  showInstructions: () ->
    for textField in @textFields()
      return true if (textField.text() && textField.text().length > 0) || textField.editorActive()
    return false
        
  activateEditor: ->
    for textField in @textFields()
      textField.activateEditor()
      
  addLanguage: (lang) ->
    instruction = new TextField(@rubricEditor, @textFields, lang, @textFieldsByLanguageId)


class Page
  constructor: (@rubricEditor) ->
    @id = ko.observable()
    @textFields = ko.observableArray()
    @namesByLanguageId = {}
    @criteria = ko.observableArray()
    @editorActive = ko.observable(false)
    @minSum = ko.observable().extend(number: true)
    @maxSum = ko.observable().extend(number: true)
    @maxSum.extend
        validation: {
            validator: (value, other) ->
              return true if !value? || value.length == 0 || !other? || other.length == 0
              return value >= other
            message: 'Must be greater than minimum'
            params: @minSum
        }
    @minSum.extend
        validation: {
            validator: (value, other) ->
              return true if !value? || value.length == 0 || !other? || other.length == 0
              return value <= other
            message: 'Must be less than maximum'
            params: @maxSum
        }
    @instructions = ko.observable(null)
    
    @sumRangeHtml = ko.computed(() ->
        min = @minSum()
        max = @maxSum()
        
        if min? && min.length > 0 || max? && max.length > 0
          "(#{if min? && min.length>0 then min else '-&infin;'} &ndash; #{if max? && max.length>0 then max else '&infin;'})"
        else
          ''
      , this)

    @editorActive.subscribe => @rubricEditor.saved = false if @rubricEditor
    @criteria.subscribe => @rubricEditor.saved = false if @rubricEditor
    @textFields.subscribe => @rubricEditor.saved = false if @rubricEditor
    
    #if data
    #  this.load_json(data)
    #else
    #  this.initializeDefault()
      
    @tabUrl = ko.computed(() ->
        return "#page-#{@id()}"
      , this)
    @tabId = ko.computed(() ->
        return "page-#{@id()}"
      , this)
    @tabLinkId = ko.computed(() ->
        return "page-#{@id()}-link"
      , this)

  initializeDefault: () ->
    @id(@rubricEditor.nextId('page'))
    @textFields([])
    for lang in @rubricEditor.languages()
      name = new TextField(@rubricEditor, @textFields, lang, @namesByLanguageId)
      name.text('Untitled Page')

    # Create instructions text fields
    instructions = new GradingInstructions(@rubricEditor)
    @instructions(instructions)
    
    criterion = new Criterion(@rubricEditor, this)
    @criteria.push(criterion)

    criterion = new Criterion(@rubricEditor, this)
    @criteria.push(criterion)

  load_json: (data) ->
    @id(@rubricEditor.nextId('page', parseInt(data['id'])))
    if @rubricEditor.multilingual 
      @textFields([]) 
      for lang in @rubricEditor.languages()
        name = new TextField(@rubricEditor, @textFields, lang, @namesByLanguageId)
        name.text(data['name'][lang.name()]) if data['name']
    else
      for lang in @rubricEditor.languages()
        name = new TextField(@rubricEditor, @textFields, lang, @namesByLanguageId)
        name.text(data['name'])
    @minSum(data['minSum'])
    @maxSum(data['maxSum'])
    
    # Create instructions text fields
    instructions = new GradingInstructions(@rubricEditor, data['instructions'])
    @instructions(instructions)

    # Load criteria
    for criterion_data in data['criteria']
      @criteria.push(new Criterion(@rubricEditor, this, criterion_data))
      
  fullName: () ->
    name = ''
    for lang in @rubricEditor.languages()
      lang_text = @namesByLanguageId[lang.id]
      if lang_text && lang_text.text() && lang_text.text().length > 0
        name = name + lang_text.text() + ' / '
      else
        name = name + 'Untitled page / '
    return name.slice(0, -2)

  to_json: ->
    criteria = @criteria().map (criterion) -> criterion.to_json()

    instructions = undefined
    instructions = @instructions().to_json() if @instructions()
    
    minSum = @minSum()
    maxSum = @maxSum()
    minSum = undefined if !$.isNumeric(minSum)
    maxSum = undefined if !$.isNumeric(maxSum)
    if minSum > maxSum
      minSum = undefined
      maxSum = undefined

    name = {}
    for text in @textFields()
      name[text.language.name()] = text.text()
    return {id: @id(), name: name, instructions: instructions, minSum: minSum, maxSum: maxSum, criteria: criteria}

    # TODO: Criteria can be dropped into page tabs
#     @tab.droppable({
#       accept: '.criterion',
#       hoverClass: 'dropHover',
#       drop: (event) => @dropCriterionToSection(event)
#       tolerance: 'pointer'
#     })

  showTab: ->
    $('#' + @tabLinkId()).tab('show')

  #
  # Deltes this page
  #
  deletePage: ->
    @rubricEditor.pages.remove(this)
    
    $('#tab-settings-link').tab('show')  # Activate first tab
    
    @rubricEditor.saved = false if @rubricEditor

  #
  # Event handler: User clicks the 'Create criterion' button
  #
  clickCreateCriterion: (event) ->
    criterion = new Criterion(@rubricEditor, this)
    @criteria.push(criterion)

    criterion.activateEditor()

  activateEditor: ->
    #@editorActive(true)
    for textField in @textFields()
      textField.activateEditor()

  addInstructions: ->
    @instructions().activateEditor() if @instructions()
    
  addLanguage: (lang) ->
    name = new TextField(@rubricEditor, @textFields, lang, @namesByLanguageId)
    for criterion in @criteria()
      criterion.addLanguage(lang)
    @instructions().addLanguage(lang) if @instructions()

class Criterion
  constructor: (@rubricEditor, @page, data) ->
    @phrases = ko.observableArray()
    @editorActive = ko.observable(false)
    @textFields = ko.observableArray()
    @namesByLanguageId = {}
    @instructions = ko.observable(null)
    
    this.load_json(data || {})
    this.initializeDefault() unless data?
    
    @editorActive.subscribe => @rubricEditor.saved = false if @rubricEditor
    @phrases.subscribe => @rubricEditor.saved = false if @rubricEditor
    @textFields.subscribe => @rubricEditor.saved = false if @rubricEditor

  load_json: (data) =>
    if data['id']
      @id = @rubricEditor.nextId('criterion', parseInt(data['id']))
    else
      @id = @rubricEditor.nextId('criterion')
      
    if @rubricEditor.multilingual 
      for lang in @rubricEditor.languages()
        name = new TextField(@rubricEditor, @textFields, lang, @namesByLanguageId)
        name.text(data['name'][lang.name()] || '') if data['name']
    else
      for lang in @rubricEditor.languages()
        name = new TextField(@rubricEditor, @textFields, lang, @namesByLanguageId)
        name.text(data['name'] || '')
    
    @minSum = ko.observable(data['minSum']).extend(number: true)
    @maxSum = ko.observable(data['maxSum']).extend(number: true)
    @maxSum.extend
        validation: {
            validator: (value, other) ->
              return true if !value? || value.length == 0 || !other? || other.length == 0
              return value >= other
            message: 'Must be greater than minimum'
            params: @minSum
        }
    @minSum.extend
        validation: {
            validator: (value, other) ->
              return true if !value? || value.length == 0 || !other? || other.length == 0
              return value <= other
            message: 'Must be less than maximum'
            params: @maxSum
        }
    
    instructions = new GradingInstructions(@rubricEditor, data['instructions'])
    @instructions(instructions)
    
    @sumRangeHtml = ko.computed(() ->
        min = @minSum()
        max = @maxSum()
        
        if min? && min.length > 0 || max? && max.length > 0
          "(#{if min? && min.length>0 then min else '-&infin;'} &ndash; #{if max? && max.length>0 then max else '&infin;'})"
        else
          ''
      , this)

    for phrase_data in (data['phrases'] || [])
      @phrases.push(new Phrase(@rubricEditor, this, phrase_data))

  initializeDefault: () ->
    phrase = new Phrase(@rubricEditor, this)
    phrase.initializeExample(1)#("What went well")
    phrase.category(0)
    @phrases.push(phrase)

    phrase = new Phrase(@rubricEditor, this)
    phrase.initializeExample(2)#("What could be improved")
    phrase.category(1)
    @phrases.push(phrase)

  to_json: ->
    phrases = @phrases().map (phrase) -> phrase.to_json()
    
    instructions = undefined
    instructions = @instructions().to_json() if @instructions()
    
    minSum = @minSum()
    maxSum = @maxSum()
    minSum = undefined if !$.isNumeric(minSum)
    maxSum = undefined if !$.isNumeric(maxSum)
    if minSum > maxSum
      minSum = undefined
      maxSum = undefined
    
    name = {}
    for text in @textFields()
      name[text.language.name()] = text.text()
    return {id: @id, name: name, minSum: minSum, maxSum: maxSum, instructions: instructions, phrases: phrases}
  
  activateEditor: ->
    #@editorActive(true)
    for textField in @textFields()
      textField.activateEditor()

  clickCreatePhrase: ->
    phrase = new Phrase(@rubricEditor, this)
    @phrases.push(phrase)

    phrase.activateEditor()

  deleteCriterion: ->
    @page.criteria.remove(this)
    
  addInstructions: ->
    @instructions().activateEditor() if @instructions()
    
  addLanguage: (lang) ->
    name = new TextField(@rubricEditor, @textFields, lang, @namesByLanguageId)
    for phrase in @phrases()
      phrase.addLanguage(lang)
    @instructions().addLanguage(lang) if @instructions()


class Phrase
  constructor: (@rubricEditor, @criterion, data) ->
    @category = ko.observable()
    @grade = ko.observable()         # Grade object
    @gradeValue = ko.observable()    # grade value (used in sum mode)
    @editorActive = ko.observable(false)
    @textFields = ko.observableArray()
    @namesByLanguageId = {}
    
    for lang in @rubricEditor.languages()
      name = new TextField(@rubricEditor, @textFields, lang, @namesByLanguageId)
    
    if data
      this.load_json(data)
    else
      @id = @rubricEditor.nextId('phrase')
    
    @editorActive.subscribe => @rubricEditor.saved = false if @rubricEditor
    @category.subscribe => @rubricEditor.saved = false if @rubricEditor
    @grade.subscribe => @rubricEditor.saved = false if @rubricEditor
    @gradeValue.subscribe => @rubricEditor.saved = false if @rubricEditor
    @textFields.subscribe => @rubricEditor.saved = false if @rubricEditor
    

  load_json: (data) ->
    @id = @rubricEditor.nextId('phrase', parseInt(data['id']))
    if @rubricEditor.multilingual 
      for lang in @rubricEditor.languages()
        name = @namesByLanguageId[lang.id]
        name.text(data['text'][lang.name()] || '') if data['text']
    else
      for lang in @rubricEditor.languages()
        name = @namesByLanguageId[lang.id]
        name.text(data['text'] || '')
    category = @rubricEditor.feedbackCategoriesById[data['category']]
    @category(category)
    
    grade = @rubricEditor.gradesByValue[data['grade']]
    @grade(grade)
    @gradeValue(data['grade'])


  to_json: ->
    content = {}
    for text in @textFields()
      content[text.language.name()] = text.text()
    json = { id: @id, text: content }
    json['category'] = @category().id if @category()
    
    # TODO: this could be less hacky
    if @rubricEditor.gradingMode() == 'sum'
      value = @gradeValue()
      if isNaN(value)
        gradeValue = value
      else
        gradeValue = parseFloat(value)
    else if @grade()
      gradeValue = @grade().to_json()
    else
      gradeValue = undefined
    
    json['grade'] = gradeValue
    
    return json

  activateEditor: ->
    #@editorActive(true)
    for textField in @textFields()
      textField.activateEditor()

  deletePhrase: ->
    @criterion.phrases.remove(this)
    
  addLanguage: (lang) ->
    name = new TextField(@rubricEditor, @textFields, lang, @namesByLanguageId)
    
  initializeExample: (example) ->
    count = 0
    for lang in @rubricEditor.languages()
      name = @namesByLanguageId[lang.id]
      continue unless name
      if count == 0 && example == 1
        name.text('What went well')
      else if count == 0
        name.text('What could be improved')
      count = count + 1
          

class Grade
  constructor: (data, @container) ->
    @value = ko.observable(data || '')
    @editorActive = ko.observable(false)
  
  # Returns a number if the value can be interpreted as a number, otherwise returns the value as a string
  to_json: ->
    value = @value()
    
    if isNaN(value)
      return value
    else
      return parseFloat(value)
  
  activateEditor: ->
    @editorActive(true)
    
  deleteGrade: () ->
    return unless @container
    @container.remove(this)


class FeedbackCategory
  constructor: (@rubricEditor, data) ->
    @editorActive = ko.observable(false)
    @textFields = ko.observableArray()
    @namesByLanguageId = {}
    
    for lang in @rubricEditor.languages()
      name = new TextField(@rubricEditor, @textFields, lang, @namesByLanguageId)
    
    @editorActive.subscribe => @rubricEditor.saved = false if @rubricEditor
  
    if data
      if data['name']
        for lang in @rubricEditor.languages()
          name = @namesByLanguageId[lang.id]
          name.text(data['name'][lang.name()] || '') if @rubricEditor.multilingual
          name.text(data['name'] || '') if !@rubricEditor.multilingual
      @id = @rubricEditor.nextId('feedbackCategory', data['id'])
    else
      @id = @rubricEditor.nextId('feedbackCategory')
  
  to_json: ->
    name = {}
    for text in @textFields()
      name[text.language.name()] = text.text()
    return {id: @id, name: name}
  
  deleteCategory: ->
    @rubricEditor.feedbackCategories.remove(this)
  
  activateEditor: ->
    #@editorActive(true)
    for textField in @textFields()
      textField.activateEditor()
  
  addLanguage: (lang) ->
    name = new TextField(@rubricEditor, @textFields, lang, @namesByLanguageId)
    
  fullName: () ->
    name = ''
    for lang in @rubricEditor.languages()
      lang_text = @namesByLanguageId[lang.id]
      if lang_text && lang_text.text() && lang_text.text().length > 0
        name = name + lang_text.text() + ' / '
      else
        name = name + 'No name / '
    return name.slice(0, -2)
    
class Language
  constructor: (@rubricEditor, data) ->
    @name = ko.observable(data || '')
    @editorActive = ko.observable(false)
    @id = @rubricEditor.nextId('language')
    @textFields = ko.observableArray()
    
    @editorActive.subscribe => @rubricEditor.saved = false if @rubricEditor
    
  to_json: ->
    value = @name()
    return value
    
  deleteLanguage: ->
    return unless @rubricEditor.languages
    @rubricEditor.languages.remove(this)
    for textField in @textFields()
      textField.deleteText()
    @textFields([])
    
  activateEditor: ->
    @editorActive(true)


class @RubricEditor
  constructor: (rawRubric, @url, @demo_mode) ->
    @saved = true
    @busySaving = ko.observable(false)
    @idCounters = {page: 0, criterion: 0, phrase: 0, feedbackCategory: 0, language: 0}
    
    @gradingMode = ko.observable('average')    # String
    @grades = ko.observableArray()             # Array of Grade objects
    @gradesByValue = {}                        # string => Grade
    @feedbackCategories = ko.observableArray() # Array of FeedbackCategory objects
    @feedbackCategoriesById = {}               # id => FeedbackCategory
    @finalComment = ko.observableArray()
    @finalCommentByLanguageId = {}
    @pages = ko.observableArray()
    @languages = ko.observableArray()

    $('.tooltip-help').popover({placement: 'left', trigger: 'hover', html: true})
    #$('#tooltip-final-comment').popover({placement: 'right', trigger: 'hover', html: true})

    unless @demo_mode
      $(window).bind 'beforeunload', => return "You have unsaved changes. Leave anyway?" unless @saved

    this.setHelpTexts()

    this.parseRubric(rawRubric)
    
    reviewTabId = $('#review_tab_id').val()
    if reviewTabId
      for page in @pages()
        if String(page.id()) == reviewTabId
          page.showTab()
    
  
  # Uses given hash {language_id: value} to sort hash values to be in same order
  # as @languages array, returns new array in right order
  sortedFields: (hash) ->
    orderedList = []
    for lang in @languages()
      orderedList.push(hash[lang.id]) if hash[lang.id]
    return orderedList
    
  # Sorts all textFields by order of @languages array
  sortAllByLanguages: () ->
    for page in @pages()
      list = this.sortedFields(page.namesByLanguageId)
      page.textFields(list) if list
      list = this.sortedFields(page.instructions().textFieldsByLanguageId) if page.instructions()
      page.instructions().textFields(list) if list
      for criterion in page.criteria()
        list = this.sortedFields(criterion.namesByLanguageId)
        criterion.textFields(list) if list
        list = this.sortedFields(criterion.instructions().textFieldsByLanguageId) if criterion.instructions()
        criterion.instructions().textFields(list) if list
        for phrase in criterion.phrases()
          list = this.sortedFields(phrase.namesByLanguageId)
          phrase.textFields(list) if list
    for category in @feedbackCategories()
      list = this.sortedFields(category.namesByLanguageId)
      category.textFields(list) if list
    list = this.sortedFields(@finalCommentByLanguageId)
    @finalComment(list) if list
  
  subscribeToChanges: ->
    notSaved = => @saved = false
    
    @grades.subscribe -> notSaved()
    @feedbackCategories.subscribe -> notSaved()
    @gradingMode.subscribe -> notSaved()
    @languages.subscribe -> notSaved()
    @languages.subscribe => this.sortAllByLanguages()
    

  setHelpTexts: ->
    $('.help-hover').each (index, element) =>
      helpElementName = $(element).data('help')

      $(element).mouseenter ->
        $('#context-help > div').hide()
        $("##{helpElementName}").show()

  # nextId('counter') returns the next available id number for 'counter'
  # nextId('counter', newId) increases the counter to newId and returns newId. If next available id is higher than newId, the counter is not increased.
  nextId: (counterName, idNumber) ->
    if idNumber?
      @idCounters[counterName] = idNumber if idNumber > @idCounters[counterName]
      return idNumber
    else
      return ++@idCounters[counterName]


  initializeDefault: ->
    @gradingMode('average')
    language = new Language(this, 'default')
    @languages.push(language)
    comment = new TextField(this, @finalComment, language, @finalCommentByLanguageId)
    #@feedbackCategories([new FeedbackCategory(this, {name: 'Strengths', id:0}),new FeedbackCategory(this, {name:'Weaknesses', id:1}),new FeedbackCategory(this, {name:'Other comments', id:2})])

    page = new Page(this)
    page.initializeDefault()
    @pages.push(page)


  #
  # Creates a new rubric page
  #
  clickCreatePage: ->
    page = new Page(this)
    page.initializeDefault()
    @pages.push(page)
    page.showTab()
    page.activateEditor()


  clickCreateCategory: ->
    originalCategoryCount = @feedbackCategories().length
    
    # Don't allow more than 3 categories
    return if originalCategoryCount >= 3
  
    new_category_count = if originalCategoryCount == 0 then 2 else 1
    for i in [0...new_category_count]
      new_category = new FeedbackCategory(this, {name: '', id: this.nextId('feedbackCategory')})
      @feedbackCategories.push(new_category)
      new_category.activateEditor()

  createGrade: () ->
    grade = new Grade('', @grades)
    @grades.push(grade)
    grade.activateEditor()
    
  clickAddLanguage: () ->
    lang = new Language(this, '')
    lang.activateEditor()
    for page in @pages()
      page.addLanguage(lang)
    for category in @feedbackCategories()
      category.addLanguage(lang)
    new TextField(this, @finalComment, lang, @finalCommentByLanguageId)
    @languages.push(lang)

  #
  # Loads the rubric by AJAX
  #
  loadRubric: (url) ->
    $.ajax
      type: 'GET'
      url: url
      error: $.proxy(@onAjaxError, this)
      dataType: 'json'
      success: (data) =>
        this.parseRubric(data)

  #
  # Parses the JSON data returned by the server. See loadRubric.
  #
  parseRubric: (data) ->
    if !data
      this.initializeDefault()
    else
      @multilingual = data['version'] == '3'
      @gradingMode(data['gradingMode'] || 'average')
      
      # Load languages and final comment
      if data['languages']
        for lang in data['languages']
          language = new Language(this, lang.toString())
          @languages.push(language)
          comment = new TextField(this, @finalComment, language, @finalCommentByLanguageId)
          comment.text(data['finalComment'][language.name()] || '') if data['finalComment'] && @multilingual
      else
        language = new Language(this, 'default')
        @languages.push(language)
        comment = new TextField(this, @finalComment, language, @finalCommentByLanguageId)
        comment.text(data['finalComment'] || '') if !@multilingual
      
      # Load feedback categories
      if data['feedbackCategories']
        for raw_category in data['feedbackCategories']
          category = new FeedbackCategory(this, raw_category)
          @feedbackCategories.push(category)
          @feedbackCategoriesById[category.id] = category

      # Load grades
      if data['grades']
        for grade in data['grades']
          if grade?
            grade = new Grade(grade.toString(), @grades)
            @grades.push(grade)
            @gradesByValue[grade.value()] = grade

      # Load pages
      for page_data in data['pages']
        page = new Page(this)
        page.load_json(page_data)
        @pages.push(page)
    
    ko.validation.init
      insertMessages: false
      decorateInputElement: true
      errorElementClass: 'invalid'
    
    ko.applyBindings(this, document.body)
    
    this.subscribeToChanges()
    @saved = true


  #
  # Sends the JSON encoded rubric to the server by AJAX
  #
  clickSaveRubric: () ->
    # Generate JSON
    pages = @pages().map (page) -> page.to_json()
    categories = @feedbackCategories().map (category) -> category.to_json()
    grades = @grades().map (grade) -> grade.to_json()
    languages = @languages().map (lang) -> lang.to_json()
    finalComment = {}
    for comment in @finalComment()
      finalComment[comment.language.name()] = comment.text()

    json = {
      version: '3'
      pages: pages
      feedbackCategories: categories
      grades: grades
      gradingMode: @gradingMode()
      finalComment: finalComment
      languages: languages
    }
    json_string = JSON.stringify(json)

    # Activate animation and disable button
    @busySaving(true)
    $('#save-message').css('opacity', 0).removeClass('success').removeClass('error')

    # AJAX call
    $.ajax
      type: 'PUT',
      url: @url,
      data: {rubric: json_string},
      error: $.proxy(@onAjaxError, this)
      dataType: 'json'
      success: (data) =>
        @saved = true
        @busySaving(false)
        $('#save-message').text('Changes saved').addClass('success').css('opacity', 1).fadeTo(5000, 0)
      error: (data) =>
        @busySaving(false)
        $('#save-message').text('Failed to save changes. Try again after a while.').addClass('error').css('opacity', 1)


  #
  # Callback for AJAX errors
  #
  onAjaxError: (jqXHR, textStatus, errorThrown) ->
    switch textStatus
      when 'timeout'
        alert('Server is not responding')
      else
        alert(errorThrown)
