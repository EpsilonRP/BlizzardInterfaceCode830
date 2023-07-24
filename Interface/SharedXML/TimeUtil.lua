
-- Set to false in some locale specific files.
TIME_UTIL_WHITE_SPACE_STRIPPABLE = true;

SECONDS_PER_MIN = 60;
SECONDS_PER_HOUR = 60 * SECONDS_PER_MIN;
SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR;
SECONDS_PER_MONTH = 30 * SECONDS_PER_DAY;
SECONDS_PER_YEAR = 12 * SECONDS_PER_MONTH;

function SecondsToMinutes(seconds)
	return seconds / SECONDS_PER_MIN;
end

function MinutesToSeconds(minutes)
	return minutes * SECONDS_PER_MIN;
end

function HasTimePassed(testTime, amountOfTime)
	return ((time() - testTime) >= amountOfTime);
end

SecondsFormatter = {};
SecondsFormatter.Abbreviation = 
{
	None = 1, -- seconds, minutes, hours...
	Truncate = 2, -- sec, min, hr...
	OneLetter = 3, -- s, m, h...
}

SecondsFormatter.Interval = {
	Seconds = 1,
	Minutes = 2,
	Hours = 3,
	Days = 4,
}

SecondsFormatter.IntervalDescription = {
	[SecondsFormatter.Interval.Seconds] = {seconds = 1, formatString = { D_SECONDS, SECONDS_ABBR, SECOND_ONELETTER_ABBR}},
	[SecondsFormatter.Interval.Minutes] = {seconds = SECONDS_PER_MIN, formatString = {D_MINUTES, MINUTES_ABBR, MINUTE_ONELETTER_ABBR}},
	[SecondsFormatter.Interval.Hours] = {seconds = SECONDS_PER_HOUR, formatString = {D_HOURS, HOURS_ABBR, HOUR_ONELETTER_ABBR}},
	[SecondsFormatter.Interval.Days] = {seconds = SECONDS_PER_DAY, formatString = {D_DAYS, DAYS_ABBR, DAY_ONELETTER_ABBR}},
}

--[[ Seconds formatter to standardize representations of seconds. When adding a new formatter
please consider if a prexisting formatter suits your needs, otherwise, before adding a new formatter,
consider adding it to a file appropriate to it's intended use. For example, "WorldQuestsSecondsFormatter"
could be added to QuestUtil.h so it's immediately apparent the scenarios the formatter is appropriate.]]

SecondsFormatterMixin = {}
-- defaultAbbreviation: the default abbreviation for the format. Can be overrridden in SecondsFormatterMixin:Format()
-- approximationSeconds: threshold for representing the seconds as an approximation (ex. "< 2 hours").
-- roundUpLastUnit: determines if the last unit in the output format string is ceiled (floored by default).
-- convertToLower: converts the format string to lowercase.
function SecondsFormatterMixin:Init(approximationSeconds, defaultAbbreviation, roundUpLastUnit, convertToLower)
	self.approximationSeconds = approximationSeconds or 0;
	self.defaultAbbreviation = defaultAbbreviation or SecondsFormatter.Abbreviation.None;
	self.roundUpLastUnit = roundUpLastUnit or false;
	self.stripIntervalWhitespace = false;
	self.convertToLower = convertToLower or false;
end

function SecondsFormatterMixin:SetStripIntervalWhitespace(strip)
	self.stripIntervalWhitespace = strip;
end

function SecondsFormatterMixin:GetStripIntervalWhitespace()
	return self.stripIntervalWhitespace;
end

function SecondsFormatterMixin:GetMaxInterval()
	return #SecondsFormatter.IntervalDescription;
end

function SecondsFormatterMixin:GetIntervalDescription(interval)
	return SecondsFormatter.IntervalDescription[interval];
end

function SecondsFormatterMixin:GetIntervalSeconds(interval)
	local intervalDescription = self:GetIntervalDescription(interval);
	return intervalDescription and intervalDescription.seconds or nil;
end

function SecondsFormatterMixin:CanApproximate(seconds)
	return (seconds > 0 and seconds < self:GetApproximationSeconds());
end

function SecondsFormatterMixin:GetDefaultAbbreviation()
	return self.defaultAbbreviation;
end

function SecondsFormatterMixin:GetApproximationSeconds()
	return self.approximationSeconds;
end

function SecondsFormatterMixin:CanRoundUpLastUnit()
	return self.roundUpLastUnit;
end

function SecondsFormatterMixin:GetDesiredUnitCount(seconds)
	return 2;
end

function SecondsFormatterMixin:GetMinInterval(seconds)
	return SecondsFormatter.Interval.Seconds;
end

function SecondsFormatterMixin:GetFormatString(interval, abbreviation, convertToLower)
	local intervalDescription = self:GetIntervalDescription(interval);
	local formatString = intervalDescription.formatString[abbreviation];
	if convertToLower then
		formatString = formatString:lower();
	end
	local strip = TIME_UTIL_WHITE_SPACE_STRIPPABLE and self:GetStripIntervalWhitespace();
	return strip and formatString:gsub(" ", "") or formatString;
end

function SecondsFormatterMixin:FormatZero(abbreviation, toLower)
	local minInterval = self:GetMinInterval(seconds);
	local formatString = self:GetFormatString(minInterval, abbreviation);
	return formatString:format(0);
end

function SecondsFormatterMixin:FormatMillseconds(millseconds, abbreviation)
	return self:Format(millseconds/1000, abbreviation);
end
function SecondsFormatterMixin:Format(seconds, abbreviation)
	if (seconds == nil) then
		return "";
	end

	seconds = math.ceil(seconds);
	abbreviation = abbreviation or self:GetDefaultAbbreviation();

	if (seconds <= 0) then
		return self:FormatZero(abbreviation);
	end

	local minInterval = self:GetMinInterval(seconds);
	local maxInterval = self:GetMaxInterval();

	if (self:CanApproximate(seconds)) then
		local interval = math.max(minInterval, SecondsFormatter.Interval.Minutes);
		while (interval < maxInterval) do
			local nextInterval = interval + 1; 
			if (seconds > self:GetIntervalSeconds(nextInterval)) then
				interval = nextInterval;
			else
				break;
			end
		end

		local formatString = self:GetFormatString(interval, abbreviation, self.convertToLower);
		local unit = formatString:format(math.ceil(seconds / self:GetIntervalSeconds(interval)));
		return string.format(LESS_THAN_OPERAND, unit);
	end
	
	local output = "";
	local appendedCount = 0;
	local desiredCount = self:GetDesiredUnitCount(seconds);
	local convertToLower = self.convertToLower;

	local currentInterval = maxInterval;
	while ((appendedCount < desiredCount) and (currentInterval >= minInterval)) do
		local intervalDescription = self:GetIntervalDescription(currentInterval);
		local intervalSeconds = intervalDescription.seconds;
		if (seconds >= intervalSeconds) then
			appendedCount = appendedCount + 1;
			if (output ~= "") then
				output = output..TIME_UNIT_DELIMITER;
			end

			local formatString = self:GetFormatString(currentInterval, abbreviation, convertToLower);
			local quotient = seconds / intervalSeconds;
			if (quotient > 0) then
				if (self:CanRoundUpLastUnit() and ((minInterval == currentInterval) or (appendedCount == desiredCount))) then
					output = output..formatString:format(math.ceil(quotient));
				else
					output = output..formatString:format(math.floor(quotient));
				end
			else
				break;
			end

			seconds = math.fmod(seconds, intervalSeconds);
		end

		currentInterval = currentInterval - 1;
	end

	-- Return the zero format if an acceptable representation couldn't be formed.
	if (output == "") then
		return self:FormatZero(abbreviation);
	end

	return output;
end