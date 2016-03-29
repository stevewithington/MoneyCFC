<!---

	This file is part of MoneyCFC
	Copyright 2016 Stephen J. Withington, Jr.
	Licensed under the Apache License, Version v2.0
	http://www.apache.org/licenses/LICENSE-2.0

	* Requires an AppID from https://openexchangerates.org
	* Be sure to check the number of requests your account is allotted per month, and select a plan accordingly

--->
<!DOCTYPE html>
<html>
<head>
	<title>MoneyCFC</title>
</head>
<body>

	<cfscript>
	fx = new money(appid='YourAppIDGoesHere');

	// Get latest rates (from prior day)
	WriteDump(fx.getExchangeRates());

	// Get historical rates (from December 12, 2012)
	WriteDump(fx.getHistoricalRates(rateDate='2012/12/12'));

	// Convert 1000.00 from USD to GBP
	WriteDump(fx.convert(amount=1000.00, from='USD', to='GBP'));

	// Convert 1000.00 from USD to GBP as of December 12, 2012
	WriteDump(fx.convert(amount=1000.00, from='USD', to='GBP', exchangeRates=fx.getHistoricalRates(rateDate='2012/12/12')));
	</cfscript>

</body>
</html>