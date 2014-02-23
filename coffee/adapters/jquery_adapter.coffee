class jQueryAdapter extends Falcon.Adapter
	cache: false

	resolveRequestType: ( data_object, type, options, context ) ->
		return super( data_object, type, options, context )
	#END resolveRequestType

	resolveContext: ( data_object, type, options, context ) ->
		return super( data_object, type, options, context )
	#END resolveContext

	standardizeOptions: ( data_object, type, options, context ) ->
		options = super( data_object, type, options, context )

		options.data = null unless isObject(options.data)
		options.dataType = "json" unless isString(options.dataType)
		options.contentType = "application/json" unless isString(options.contentType)
		options.params = {} unless isObject( options.params )
		options.headers = {} unless isObject( options.headers )
		options.cache = @cache

		return options
	#END standardizeOptions

	makeUrl: ( data_object, type, options, context ) ->
		url = super( data_object, type, options, context )

		unless isEmpty( options.params )
			url += "?" unless url.indexOf("?") > -1
			url += ( "#{key}=#{value}" for key, value of options.params ).join("&")
		#END unless

		return url
	#END makeUrl

	serializeData: ( data_object, type, options, context ) ->
		serialized_data = super( data_object, type, options, context )
		return "" if serialized_data is null
		return JSON.stringify(options.data)
	#END serializeData

	parseRawResponseData: ( data_object, type, options, context, response_args ) ->
		{data, xhr} = super( data_object, type, options, context, response_args )
		data = JSON.parse( data ) if isString( data )
		data = JSON.parse( xhr.responseText ) if not data? and isString( xhr.responseText )
		data ?= if Falcon.isModel( data_object ) then {} else []
		return data
	#END parseRawResponseData

	successResponseHandler: ( data_object, type, options, context, response_args ) ->
		super( data_object, type, options, context, response_args )
	#END successResponseHandler

	errorResponseHandler: ( data_object, type, options, context, response_args ) ->
		super( data_object, type, options, context, response_args )
	#END errorResponseHandler

	completeResponseHandler: ( data_object, type, options, context, response_args ) ->
		super( data_object, type, options, context, response_args )
	#END  completeResponseHandler

	sync: ( data_object, type, options, context ) ->
		super( data_object, type, options, context )

		type = @resolveRequestType( data_object, type, options, context )
		options = @standardizeOptions( data_object, type, options, context )
		context = @resolveContext( data_object, type, options, context )

		#Validate any models that are trying to be created or saved
		if Falcon.isModel( data_object )
			return null if (type in ["PUT", "POST"]) and (not data_object.validate(options))
		#END if

		url = @makeUrl( data_object, type, options, context )
		data = @serializeData( data_object, type, options, context ) 

		return $.ajax
			'type': type
			'url': url
			'data': data
			'dataType': options.dataType
			'contentType': options.contentType
			'cache': options.cache
			'headers': options.headers

			'success': (data, status, xhr) =>
				@successResponseHandler( data_object, type, options, context, {
					'data': data,
					'status': status,
					'xhr': xhr
				})
			#END success

			'error': (xhr) =>
				@errorResponseHandler( data_object, type, options, context, {
					'xhr': xhr
				})
			#END error

			'complete': (xhr, status) =>
				@completeResponseHandler( data_object, type, options, context, {
					'status': status,
					'xhr': xhr
				})
			#END complete
		#END $.ajax
	#END sync

	getTemplate: (view, url, loaded_callback) ->
		if url.charAt(0) is "#"
			return super( view, url, loaded_callback )
		else
			$.ajax
				url: url
				type: "GET"
				cache: @cache
				error: () =>
					console.log("[FALCON] Error Loading Template: '#{url}'")
				#END error
				success: (html) =>
					Falcon.View.cacheTemplate(url, html)
					loaded_callback() if isFunction( loaded_callback )
				#END success
			#END ajax
		#END if

		return @
	#END getTemplate
#END class

Falcon.adapter = new jQueryAdapter