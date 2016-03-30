# MoneyCFC

Foreign currency exchange rates for CFML/ColdFusion based on the [money.js / fx() project](http://openexchangerates.github.io/money.js/)

* Requires an AppID from https://openexchangerates.org
* Be sure to check the number of requests your account is allotted per month, and select a plan accordingly

## Examples

```
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
```

## License
Copyright 2016 Stephen J. Withington, Jr.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this work except in compliance with the License. You may obtain a copy of the License in the LICENSE file, or at:

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.