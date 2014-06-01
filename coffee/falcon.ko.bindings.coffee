#--------------------------------------------------------
# Method: ko.bindingHandlers.view
#	Mehod used to handle view objects, fetching their html
#	and binding them against their memebr objects
#--------------------------------------------------------
ko.bindingHandlers['view'] = do ->
	_standardizeOptions = (valueAccessor) ->
		options = valueAccessor()
		options = {data: options} if Falcon.isView( options ) or ko.isObservable( options )
		options = {} unless isObject(options)
		options['data'] ?= null
		options['displayIf'] ?= true
		options['afterDisplay'] ?= null
		options['beforeDispose'] ?= null
		return options
	#END _standardizeOptions

	_runUnobserved = (callback, context) ->
		computed = ko.computed -> callback.call(context ? this)
		computed.peek()
		computed.dispose()
	#END _runUnobserved

	'init': (element, valueAccessor, allBindingsAccessor, viewModel, context) ->
		view = null
		oldView = null
		is_displayed = false
		is_disposing = false
		continuation = (->)

		container = document.createElement('div')

		anonymous_template = new ko.templateSources.anonymousTemplate(element)
		anonymous_template['nodes'](container)
		anonymous_template['text']("")

		ko.utils.domNodeDisposal.addDisposeCallback element, ->
			_view = ko.unwrap( view )
			_view._unrender() if Falcon.isView( _view )
		#END domDisposal

		ko.computed
			disposeWhenNodeIsRemoved: element
			read: ->
				options = _standardizeOptions(valueAccessor)
				view = ko.unwrap( options.data )

				template = if Falcon.isView( view ) then ko.unwrap(view.__falcon_view__loaded_template__) else "" 
				template = "" unless isString(template)

				afterDisplay = ko.utils.peekObservable( options['afterDisplay'] )
				beforeDispose = ko.utils.peekObservable( options['beforeDispose'] )
				
				should_display = ko.unwrap( options['displayIf'] ) isnt false
				should_display = should_display and not isEmpty( template )

				continuation = ->
					continuation = (->)
					is_disposing = false
					is_displayed = false

					if view isnt oldView
						if Falcon.isView( oldView ) and oldView.__falcon_view__is_rendered__
							_runUnobserved(oldView._unrender, oldView)
						#END if

						oldView = view
					#END if

					unless should_display
						_runUnobserved(view._unrender, view) if Falcon.isView( view )
						return ko.virtualElements.emptyNode(element)
					#END unless
					
					childContext = context.createChildContext(viewModel).extend( '$view': view.createViewModel() )
							
					container.innerHTML = template
					anonymous_template['text'](template)
					
					ko.renderTemplate(element, childContext, {}, element)

					is_displayed = true

					_runUnobserved(view._render, view)

					if isFunction(afterDisplay)
						afterDisplay( ko.virtualElements.childNodes(element), view )
					#END if
				#END continuation

				return if is_disposing

				if is_displayed and isFunction(beforeDispose)
					if ( beforeDispose.__falcon_bind__length__ ? beforeDispose.length ) is 3
						is_disposing = true
						beforeDispose ko.virtualElements.childNodes(element), view, ->
							continuation()
						#END beforeDispose
					else
						beforeDispose( ko.virtualElements.childNodes(element), view )
						continuation()
					#END if
				else
					continuation()
				#END if
			#END read
		#END computed

		return { controlsDescendantBindings: true }
	#END init
#END view binding handler


#--------------------------------------------------------
# Method: ko.bindingHandlers.foreach
#	Override the default foreach handler to also take into account
#	Falcon collection objects
#--------------------------------------------------------
#Interal method used to get a the expected models
_getForeachItems = (value) ->
	value = ko.utils.peekObservable( value )
	value = {data: value} if Falcon.isCollection( value ) or isArray( value )
	value = {} unless isObject( value )

	value.data = ko.unwrap( value.data )
	value.data = value.data.models() if Falcon.isCollection( value.data )
	value.data ?= []

	return ( -> value )
#END _getForeachItems

#Store a copy of the old foreach
Falcon.__binding__original_foreach__ = ko.bindingHandlers['foreach'] ? {}
ko.bindingHandlers['foreach'] = 
	'init': (element, valueAccessor, args...) ->
		value = ko.unwrap( valueAccessor() )
		return Falcon.__binding__original_foreach__['init'](element, _getForeachItems(value), args...)
	#END init

	'update': (element, valueAccessor, args...) ->
		value = ko.unwrap( valueAccessor() )
		return Falcon.__binding__original_foreach__['update'](element, _getForeachItems(value), args...)
	#END update
#END foreach override

#Map the rest of the values in, right now is just makeValueTemplateAccessor
for key, value of Falcon.__binding__original_foreach__ when key not of ko.bindingHandlers['foreach']
	ko.bindingHandlers['foreach'][key] = value
#END for

#--------------------------------------------------------
# Method: ko.bindingHandlers.options
#	override the options binding to account for collections
#--------------------------------------------------------
_getOptionsItems = (value) ->
	value = ko.unwrap( value )
	value = value.models() if Falcon.isCollection( value )

	return ( -> value )
#END _getOptionsItems

Falcon.__binding__original_options__ = ko.bindingHandlers['options'] ? (->)
ko.bindingHandlers['options'] = do ->
	'init': (element, valueAccessor, args...) ->
		value = ko.unwrap( valueAccessor() )
		return ( Falcon.__binding__original_options__['init'] ? (->) )(element, _getOptionsItems(value), args...)
	#END init

	'update': (element, valueAccessor, args...) ->
		value = ko.unwrap( valueAccessor() )
		return ( Falcon.__binding__original_options__['update'] ? (->) )(element, _getOptionsItems(value), args...)
	#END update
#END options override

#Map the rest of the values from the original binding
for key, value of Falcon.__binding__original_options__ when key not of ko.bindingHandlers['options']
	ko.bindingHandlers['options'][key] = value
#END for

#--------------------------------------------------------
# Method: ko.bindingHandlers.log
#	Debug binding to log observable values
#--------------------------------------------------------
ko.bindingHandlers['log'] =
	update: (element, valueAccessor) ->
		console.log( ko.unwrap( valueAccessor() ) )
	#END update
#END log


#--------------------------------------------------------
# Extends onto the context varibales utilized in knockout templating
# to include $view (to access this view's members easily)
#--------------------------------------------------------

#Define which bindings should be allowed to be virtual
ko.virtualElements.allowedBindings['view'] = true
ko.virtualElements.allowedBindings['log'] = true