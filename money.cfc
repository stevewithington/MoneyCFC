/*

	This file is part of MoneyCFC
	Copyright 2016 Stephen J. Withington, Jr.
	Licensed under the Apache License, Version v2.0
	http://www.apache.org/licenses/LICENSE-2.0

	* Requires an AppID from https://openexchangerates.org
	* Be sure to check the number of requests your account is allotted per month, and select a plan accordingly

*/
component persistent="false" accessors="true" output="false" displayname="MoneyCFC" {
	property name="appid" type="string" default="";
	property name="ratesdirectory" type="string" default="";

	public any function init(required string appid, string ratesdir=GetDirectoryFromPath(GetCurrentTemplatePath())) {
		var fileDelim = getFileDelim();
		var ratesDirectory = arguments.ratesdir & fileDelim & 'exchange-rates';

		if ( !DirectoryExists(ratesDirectory) ) {
			DirectoryCreate(ratesDirectory);
		}

		setRatesDirectory(ratesDirectory);
		setAppID(arguments.appid);
		return this;
	}

	public any function getExchangeRates() {
		// This will create two files: 1) yyyy-mm-dd.json, and 2) latest.json if they don't already exist
		// It will also update the latest.json file to rates as of the close of previous day
		var fileDelim = getFileDelim();
		var yesterdaysDate = DateFormat(DateAdd('d', -1, Now()), 'yyyy-mm-dd');
		var formattedFilename = getRatesDirectory() & fileDelim & yesterdaysDate & '.json';
		var latestFilename = getRatesDirectory() & fileDelim & 'latest.json';

		// First, check to see if we should update the rates ...
		if ( !FileExists(formattedFilename) || !FileExists(latestFilename) ) {
			var openExchangeRatesApiUrl = 'https://openexchangerates.org/api/historical/' & yesterdaysDate & '.json?app_id=' & getAppID();

			try {
				var resp = new http();
						resp
							.setMethod('GET')
							.setURL(openExchangeRatesApiUrl)
							.setPort(443)
							.setTimeout(60)
							.setResolveURL(false);

				var filecontent = resp.send().getPrefix().filecontent;

				if ( IsJSON(filecontent) ) {
					try {
						FileWrite(formattedFilename, filecontent);
						FileWrite(latestFilename, filecontent);
					} catch(any e) {
						//return e; // this will only appear in the console
						result = {
							'error'=true
							, 'status'=400
							, 'content'=e.message
							, 'detail'=e.detail
						}
					}
				}
			} catch (any e) {
				//return e; // this will only appear in the console
				result = {
					'error'=true
					, 'status'=400
					, 'content'=e.message
					, 'detail'=e.detail
				}
			}
		}

		// Even if we ran into an issue, we may still have the latest rates
		if ( FileExists(latestFilename) ) {
			var objFile = FileRead(latestFilename);
			result = {
				'error'=false
				, 'status'=200
				, 'content'=objFile
			};
		}

		return result;
	}

	// Use this method to get rates based on a specified date ... defaults to previous day's date
	public any function getHistoricalRates(date rateDate=DateAdd('d', -1, Now())) {
		var fileDelim = getFileDelim();
		var formattedRateDate = DateFormat(arguments.rateDate, 'yyyy-mm-dd');
		var formattedFilename = getRatesDirectory() & fileDelim & formattedRateDate & '.json';

		// First, check to see if we should update the rates ...
		if ( !FileExists(formattedFilename) ) {
			var openExchangeRatesApiUrl = 'https://openexchangerates.org/api/historical/' & formattedRateDate & '.json?app_id=' & getAppID();

			try {
				var resp = new http();
						resp
							.setMethod('GET')
							.setURL(openExchangeRatesApiUrl)
							.setPort(443)
							.setTimeout(60)
							.setResolveURL(false);

				var filecontent = resp.send().getPrefix().filecontent;

				if ( IsJSON(filecontent) ) {
					try {
						FileWrite(formattedFilename, filecontent);
					} catch(any e) {
						//return e; // this will only appear in the console
						result = {
							'error'=true
							, 'status'=400
							, 'content'=e.message
							, 'detail'=e.detail
						}
					}
				}
			} catch (any e) {
				//return e; // this will only appear in the console
				result = {
					'error'=true
					, 'status'=400
					, 'content'=e.message
					, 'detail'=e.detail
				}
			}
		}

		if ( FileExists(formattedFilename) ) {
			var objFile = FileRead(formattedFilename);
			result = {
				'error'=false
				, 'status'=200
				, 'content'=objFile
			};
		}

		return result;
	}	

	// usage:  convert(val='100.00', from='USD', to='GBP');
	public string function convert(required any amount, string from='USD', string to='USD', exchangeRates=getExchangeRates()) {

		if ( !IsNumeric(arguments.amount) ) {
			return '';
		}

		// Just in case someone passes in an empty argument
		arguments.from = Len(arguments.from) ? arguments.from : 'USD';
		arguments.to = Len(arguments.to) ? arguments.to : arguments.from;

		if ( !IsStruct(arguments.exchangeRates) ) {
			Throw(message='Invalid exchangeRates submitted!');
		}

		if ( StructKeyExists(arguments.exchangeRates, 'error') && !arguments.exchangeRates.error && StructKeyExists(arguments.exchangeRates, 'content') ) {
			// we're good
			var jsonRates = arguments.exchangeRates.content;
			if ( IsJSON(jsonRates) ) {
				var fxRates = DeserializeJSON(jsonRates);

				// should have 'base' and 'rates' keys
				if ( StructKeyExists(fxRates, 'base') && StructKeyExists(fxRates, 'rates') ) {
					// still good!

					// Check to make sure that both 'from' and 'to' exists in 'fxRates'
						if ( !StructKeyExists(fxRates.rates, arguments.from) || !StructKeyExists(fxRates.rates, arguments.to) ) {
							Throw(message='Invalid currency submitted.', detail='The submitted currencies were FROM: (#arguments.from#) and TO: (#arguments.to#).');
						}

						// package up all of the data for easier debugging
						fxRates['from'] = arguments.from;
						fxRates['to'] = arguments.to;
						fxRates['result'] = arguments.amount * getExchangeRate(fxRates=fxRates, from=arguments.from, to=arguments.to);

						return fxRates.result;
						//return NumberFormat(result, '_.99');
				} // @END proper keys
			} // @END isJSON
		} // @END no error

		return ''; // ERROR ~ but don't bomb the app
	}

	// only used by convert()
	private numeric function getExchangeRate(required struct fxRates, string from='USD', string to='USD') {
		var rates = arguments.fxRates.rates;

		// Make sure the base rate is in the rates object:
		rates[fxRates.base] = 1;

		// Throw an error if either rate isn't in the rates array
		if ( !StructKeyExists(rates, arguments.to) || !StructKeyExists(rates, arguments.from) ) {
			Throw(message='Invalid currency submitted.', detail='The submitted currencies were FROM: (#arguments.from#) and TO: (#arguments.to#).');
		}

		// If 'from' currency === fx.base, return the basic exchange rate for the 'to' currency
		if ( arguments.from == fxRates.base ) {
			return rates[arguments.to];
		}

		// If 'to' currency == fx.base, return the basic inverse rate of the 'from' currency
		if ( arguments.to == fxRates.base ) {
			return 1 / rates[arguments.from];
		}

		// Otherwise, return the 'to' rate multipled by the inverse of the 'from' rate to get the
		// relative exchange rate between the two currencies
		return rates[arguments.to] * (1 / rates[arguments.from]);
	}

	// http://www.exchangerates.org.uk/currency-symbols.html
	public any function getCurrencyOptions() {
		return {
			'ARS'='Argentine Peso'
			, 'AUD'='Australian Dollar'
			, 'BBD'='Barbadian Dollar'
			, 'BRL'='Brazilian Real'
			, 'GBP'='British Pound'
			, 'CAD'='Canadian Dollar'
			, 'CLP'='Chilean Peso'
			, 'CNY'='Chinese Yuan'
			, 'CZK'='Czech Koruna'
			, 'DKK'='Danish Krone'
			, 'XCD'='East Caribbean Dollar'
			, 'EGP'='Egyptian Pound'
			, 'EEK'='Estonian Kroon'
			, 'EUR'='Euro'
			, 'HKD'='Hong Kong Dollar'
			, 'HUF'='Hungarian Forint '
			, 'ISK'='Icelandic Krona'
			, 'INR'='Indian Rupee'
			, 'IDR'='Indonesian Rupiah'
			, 'ILS'='Israeli Sheqel'
			, 'JMD'='Jamaican Dollar'
			, 'JPY'='Japanese Yen'
			, 'JOD'='Jordanian Dinar'
			, 'LVL'='Latvian Lats'
			, 'LBP'='Lebanese Pound'
			, 'LTL'='Lithuanian Litas'
			, 'MOP'='Macanese Pataca'
			, 'MYR'='Malaysian Ringgit'
			, 'MXN'='Mexican Peso'
			, 'NAD'='Namibian Dollar'
			, 'NPR'='Nepalese Rupee'
			, 'NZD'='New Zealand Dollar'
			, 'NOK'='Norwegian Krone'
			, 'OMR'='Omani Rial'
			, 'PKR'='Pakastani Rupee'
			, 'PAB'='Panamanian Balboa'
			, 'PHP'='Philippine Peso'
			, 'PLN'='Polish Zloty'
			, 'QAR'='Qatari Riyal'
			, 'RON'='Romanian Leu'
			, 'RUB'='Russian Rouble'
			, 'SAR'='Saudi Riyal'
			, 'SGD'='Singapore Dollar'
			, 'ZAR'='South African Rand'
			, 'KRW'='South Korean Won'
			, 'LKR'='Sri Lankan Rupee'
			, 'SEK'='Swedish Krona'
			, 'CHF'='Swiss Franc'
			, 'THB'='Thai Baht'
			, 'TRY'='Turkish Lira'
			, 'USD'='U.S. Dollar'
			, 'VEF'='Venezuelan Bolivar'
		};
	}

	public any function getFileDelim() {
		var objFile = CreateObject('java', 'java.io.File');
		return objFile.separator;
	}
}