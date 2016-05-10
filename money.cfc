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
			'USD'='US Dollar'
			, 'EUR'='Euro'
			, 'ALL'='Albanian Lek'
			, 'DZD'='Algerian Dinar'
			, 'AOA'='Angolan Kwanza'
			, 'ARS'='Argentine Peso'
			, 'AMD'='Armenian Dram'
			, 'AWG'='Aruban Florin'
			, 'AUD'='Australian Dollar'
			, 'AZN'='Azerbaijani Manat'
			, 'BSD'='Bahamian Dollar'
			, 'BHD'='Bahraini Dinar'
			, 'BDT'='Bangladeshi Taka'
			, 'BBD'='Barbadian Dollar'
			, 'BYR'='Belarusian Ruble'
			, 'BEF'='Belgian Franc'
			, 'BZD'='Belize Dollar'
			, 'BMD'='Bermudan Dollar'
			, 'BTN'='Bhutanese Ngultrum'
			, 'BTC'='Bitcoin'
			, 'BOB'='Bolivian Boliviano'
			, 'BAM'='Bosnia-Herzegovina Convertible Mark'
			, 'BWP'='Botswanan Pula'
			, 'BRL'='Brazilian Real'
			, 'GBP'='British Pound'
			, 'BND'='Brunei Dollar'
			, 'BGN'='Bulgarian Lev'
			, 'BIF'='Burundian Franc'
			, 'KHR'='Cambodian Riel'
			, 'CAD'='Canadian Dollar'
			, 'CVE'='Cape Verdean Escudo'
			, 'KYD'='Cayman Islands Dollar'
			, 'XAF'='Central African CFA Franc'
			, 'XPF'='CFP Franc'
			, 'CLP'='Chilean Peso'
			, 'CNY'='Chinese Yuan'
			, 'COP'='Colombian Peso'
			, 'KMF'='Comorian Franc'
			, 'CDF'='Congolese Franc'
			, 'CRC'='Costa Rican Colón'
			, 'HRK'='Croatian Kuna'
			, 'CUC'='Cuban Convertible Peso'
			, 'CZK'='Czech Republic Koruna'
			, 'DKK'='Danish Krone'
			, 'DJF'='Djiboutian Franc'
			, 'DOP'='Dominican Peso'
			, 'XCD'='East Caribbean Dollar'
			, 'EGP'='Egyptian Pound'
			, 'ERN'='Eritrean Nakfa'
			, 'EEK'='Estonian Kroon'
			, 'ETB'='Ethiopian Birr'
			, 'FKP'='Falkland Islands Pound'
			, 'FJD'='Fijian Dollar'
			, 'GMD'='Gambian Dalasi'
			, 'GEL'='Georgian Lari'
			, 'DEM'='German Mark'
			, 'GHS'='Ghanaian Cedi'
			, 'GIP'='Gibraltar Pound'
			, 'GRD'='Greek Drachma'
			, 'GTQ'='Guatemalan Quetzal'
			, 'GNF'='Guinean Franc'
			, 'GYD'='Guyanaese Dollar'
			, 'HTG'='Haitian Gourde'
			, 'HNL'='Honduran Lempira'
			, 'HKD'='Hong Kong Dollar'
			, 'HUF'='Hungarian Forint'
			, 'ISK'='Icelandic Kr&##xF3;na'
			, 'INR'='Indian Rupee'
			, 'IDR'='Indonesian Rupiah'
			, 'IRR'='Iranian Rial'
			, 'IQD'='Iraqi Dinar'
			, 'ILS'='Israeli New Sheqel'
			, 'ITL'='Italian Lira'
			, 'JMD'='Jamaican Dollar'
			, 'JPY'='Japanese Yen'
			, 'JOD'='Jordanian Dinar'
			, 'KZT'='Kazakhstani Tenge'
			, 'KES'='Kenyan Shilling'
			, 'KWD'='Kuwaiti Dinar'
			, 'KGS'='Kyrgystani Som'
			, 'LAK'='Laotian Kip'
			, 'LVL'='Latvian Lats'
			, 'LBP'='Lebanese Pound'
			, 'LSL'='Lesotho Loti'
			, 'LRD'='Liberian Dollar'
			, 'LYD'='Libyan Dinar'
			, 'LTL'='Lithuanian Litas'
			, 'MOP'='Macanese Pataca'
			, 'MKD'='Macedonian Denar'
			, 'MGA'='Malagasy Ariary'
			, 'MWK'='Malawian Kwacha'
			, 'MYR'='Malaysian Ringgit'
			, 'MVR'='Maldivian Rufiyaa'
			, 'MRO'='Mauritanian Ouguiya'
			, 'MUR'='Mauritian Rupee'
			, 'MXN'='Mexican Peso'
			, 'MDL'='Moldovan Leu'
			, 'MNT'='Mongolian Tugrik'
			, 'MAD'='Moroccan Dirham'
			, 'MMK'='Myanmar Kyat'
			, 'NAD'='Namibian Dollar'
			, 'NPR'='Nepalese Rupee'
			, 'ANG'='Netherlands Antillean Guilder'
			, 'TWD'='New Taiwan Dollar'
			, 'NZD'='New Zealand Dollar'
			, 'NIO'='Nicaraguan Córdoba'
			, 'NGN'='Nigerian Naira'
			, 'KPW'='North Korean Won'
			, 'NOK'='Norwegian Krone'
			, 'OMR'='Omani Rial'
			, 'PKR'='Pakistani Rupee'
			, 'PAB'='Panamanian Balboa'
			, 'PGK'='Papua New Guinean Kina'
			, 'PYG'='Paraguayan Guarani'
			, 'PEN'='Peruvian Nuevo Sol'
			, 'PHP'='Philippine Peso'
			, 'PLN'='Polish Zloty'
			, 'QAR'='Qatari Rial'
			, 'RON'='Romanian Leu'
			, 'RUB'='Russian Ruble'
			, 'RWF'='Rwandan Franc'
			, 'SVC'='Salvadoran Colón'
			, 'WST'='Samoan Tala'
			, 'SAR'='Saudi Riyal'
			, 'RSD'='Serbian Dinar'
			, 'SCR'='Seychellois Rupee'
			, 'SLL'='Sierra Leonean Leone'
			, 'SGD'='Singapore Dollar'
			, 'SKK'='Slovak Koruna'
			, 'SBD'='Solomon Islands Dollar'
			, 'SOS'='Somali Shilling'
			, 'ZAR'='South African Rand'
			, 'KRW'='South Korean Won'
			, 'XDR'='Special Drawing Rights'
			, 'LKR'='Sri Lankan Rupee'
			, 'SHP'='St. Helena Pound'
			, 'SDG'='Sudanese Pound'
			, 'SRD'='Surinamese Dollar'
			, 'SZL'='Swazi Lilangeni'
			, 'SEK'='Swedish Krona'
			, 'CHF'='Swiss Franc'
			, 'SYP'='Syrian Pound'
			, 'STD'='São Tomé & Príncipe Dobra'
			, 'TJS'='Tajikistani Somoni'
			, 'TZS'='Tanzanian Shilling'
			, 'THB'='Thai Baht'
			, 'TOP'='Tongan Paʻanga'
			, 'TTD'='Trinidad & Tobago Dollar'
			, 'TND'='Tunisian Dinar'
			, 'TRY'='Turkish Lira'
			, 'TMT'='Turkmenistani Manat'
			, 'UGX'='Ugandan Shilling'
			, 'UAH'='Ukrainian Hryvnia'
			, 'AED'='United Arab Emirates Dirham'
			, 'UYU'='Uruguayan Peso'
			, 'UZS'='Uzbekistani Som'
			, 'VUV'='Vanuatu Vatu'
			, 'VEF'='Venezuelan Bolívar'
			, 'VND'='Vietnamese Dong'
			, 'XOF'='West African CFA Franc'
			, 'YER'='Yemeni Rial'
		};
	}

	public any function getFileDelim() {
		var objFile = CreateObject('java', 'java.io.File');
		return objFile.separator;
	}
}