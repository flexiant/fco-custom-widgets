--[[
Twitter User Feed Widget Provider
© 2015 Flexiant Ltd

This FDL code block defines a custom widget pluggable resource provider that will allow
the creation of widgets that will display tweets posted and retweeted by a specified user.

{"FDLINFO":{"NAME":"Twitter User Feed Widget","VERSION":"1.0.0"}}
]]

function register()
  return { "twitter_widget_provider" }
end

function twitter_widget_provider()
  local widgetHelper = new("FDLCustomWidgetHelper");

  local pctParams = {};
  table.insert(pctParams, widgetHelper:getRefreshTimeValueDefinition(true));
  table.insert(pctParams, widgetHelper:getResourceDescriptionValueDefinition(true));
  table.insert(pctParams, widgetHelper:getResourceIconValueDefinition(true));

  local actionFunctions = {};
  table.insert(actionFunctions, widgetHelper:getContentActionDefinition("get_content_function", {"BE", "CUSTOMER"}, nil, true));

  return{
    api="PLUGGABLE_PROVIDER",
    version=1,
    ref="markdown_widget_provider",
    name="#__TWITTER_FEED_WIDGET_NAME",
    description="#__TWITTER_FEED_WIDGET_DESCRIPTION",
    providerType="TWITTER_FEED_WIDGET",
    providerGroup="SKYLINE_CUSTOM_WIDGET",
    providerIcon="FONT_ICON_RETWEET",
    createFunction={executionFunction="create_function", invocationLevel={"BE"}},
    deleteFunction={executionFunction="delete_function", invocationLevel={"BE"}},
    modifyFunction={executionFunction="modify_function", invocationLevel={"BE"}},
    advertiseFunction={executionFunction="advertise_function"},
    productComponentTypes={
      {
        name="#__TWITTER_WIDGET_PCT_DISPLAY_NAME",
        referenceField="TWITTER_WIDGET_DISPLAY_PCT",
        optional=false,
        configurableList=pctParams
      },
      {
        name="#__TWITTER_WIDGET_PCT_SETUP_NAME",
        referenceField="TWITTER_WIDGET_SETUP_PCT",
        optional=false,
        configurableList={
          {
            key="api_key",
            name="#__TWITTER_WIDGET_API_KEY_NAME",
            description="#__TWITTER_WIDGET_API_KEY_DESCRIPTION"
          },
          {
            key="api_secret",
            name="#__TWITTER_WIDGET_API_SECRET_NAME",
            description="#__TWITTER_WIDGET_API_SECRET_DESCRIPTION"
          }
        }
      },
      {
        name="#__TWITTER_WIDGET_PCT_FEED_NAME",
        referenceField="TWITTER_WIDGET_FEED_PCT",
        optional=true,
        configurableList={
          {
            key="screen_name",
            name="#__TWITTER_WIDGET_SCREEN_NAME_NAME",
            description="#__TWITTER_WIDGET_SCREEN_NAME_DESCRIPTION",
            required=true
          },
          {
            key="max_tweets",
            name="#__TWITTER_WIDGET_MAX_TWEETS_NAME",
            description="#__TWITTER_WIDGET_MAX_TWEETS_DESCRIPTION",
            defaultValue=50,
            validator={
              validatorType="NUMERIC_INT",
              validateString="10-200"
            }
          },
          {
            key="include_retweets",
            name="#__TWITTER_WIDGET_INC_RETWEETS_NAME",
            description="#__TWITTER_WIDGET_INC_RETWEETS_DESCRIPTION",
            validator={
              validatorType="BOOLEAN"
            }
          }
        }
      }
    },
    actionFunctions=actionFunctions
  }
end

function get_content_function(p)

  local simplehttp = new("simplehttp");

  local connection=simplehttp:newConnection({ enable_cookie=true, ssl_verify=true })

  local providerMap = dataStore:getPrivateDataMap(p.resource:getResourceUUID());
  if(providerMap == nil or providerMap:containsKey("api_secret") == false) then
    return {
      returnCode = "FAILED",
      errorCode="401",
      errorString=translate.string("#__TWITTER_FEED_ERROR_MISSING_SECRET");
    }
  end

  local apiKey = providerMap:get("api_key");
  local apiSecret = providerMap:get("api_secret");
  if(apiKey == nil or #apiKey == 0 or apiSecret == nil or #apiSecret == 0) then
    return {
      returnCode = "FAILED",
      errorCode="401",
      errorString=translate.string("#__TWITTER_FEED_ERROR_MISSING_SECRET");
    }
  end
  local validateResult = validateAPIKeyAndAPISecret(connection, apiKey, apiSecret);
  if(validateResult.success == false) then
    return validateResult;
  end

  local json = new("JSON");
  local response = json:decode(validateResult.response);
  if(response.token_type == nil or response.token_type ~= "bearer") then
    return {
      returnCode = "FAILED",
      errorCode="502",
      errorString="Invalid response from API"
    }
  end

  local headers = {}
  headers["Content-Type"] = "application/x-www-form-urlencoded;charset=UTF-8";
  headers["Authorization"] = "Bearer "..response.access_token;

  local screen_name = p.resourceValues.screen_name;
  local max_tweets = p.resourceValues.max_tweets;
  if(max_tweets == nil) then
    max_tweets = 50;
  elseif(tonumber(max_tweets) > 200) then
    max_tweets = 200;
  elseif(tonumber(max_tweets) < 1) then
    max_tweets = 50;
  end

  local include_retweets = p.resourceValues.include_retweets;
  if(include_retweets ~= nil and (include_retweets == "true" or include_retweets == "1" or include_retweets == "TRUE")) then
    include_retweets = "true";
  else
    include_retweets = "false";
  end

  local params = "screen_name="..screen_name.."&count="..max_tweets.."&trim_user=false&exclude_replies=true&include_rts="..include_retweets;

  local url = "https://api.twitter.com/1.1/statuses/user_timeline.json?"..params;

  local apiResult = makeAPICall(connection,url,"GET","",headers,false);
  if(apiResult.success == false) then
    local response = json:decode(apiResult.response);
    if(response ~= nil) then
    
      if(response.errors ~= nil and #response.errors > 0) then
        return {
          returnCode = "FAILED",
          errorCode=response.errors[1].code,
          errorString=response.errors[1].message
        }
      end
      
      if(response.error ~= nil) then
        return {
          returnCode = "FAILED",
          errorCode=apiResult.statusCode,
          errorString=response.error
        }
      end
    end
    
    return {
      returnCode = "FAILED",
      errorCode=apiResult.statusCode,
      errorString=apiResult.response
    }
  end
  local response = json:decode(apiResult.response);

  local dateHelper = new("FDLDateHelper");

  local tweets = {};
  for i = 1, #response, 1 do

    local tweet = response[i];

    tweets[i] = {};
    tweets[i].retweet = false;

    if(tweet.retweeted_status ~= nil) then
      tweets[i].retweet = true;

      tweets[i].retweetedBy = {};
      tweets[i].retweetedBy.id = tweet.user.id_str;
      tweets[i].retweetedBy.name = tweet.user.name;
      tweets[i].retweetedBy.profile_image_url = tweet.user.profile_image_url_https;
      tweets[i].retweetedBy.screen_name = tweet.user.screen_name;
      tweets[i].retweetedBy.description = tweet.user.description;
      tweets[i].retweetedBy.verified = tweet.user.verified;

      tweet = tweet.retweeted_status;
    end

    tweets[i].images = {};
    tweets[i].user_mentions = {};
    tweets[i].hashtags = {};
    tweets[i].urls = {};

    if(tweet.entities ~= nil) then
      local media = tweet.entities.media;
      if(media ~= nil and #media > 0) then
        for j = 1, #media, 1 do
          local item = media[j];

          if(item ~= nil and item.type == "photo") then
            local image = {};
            image.url = item.url;
            image.media_url = item.media_url_https;
            image.display_url = item.display_url;
            image.width = item.sizes.small.w;
            image.height = item.sizes.small.h;

            table.insert(tweets[i].images, image);
          end

        end
      end

      local user_mentions = tweet.entities.user_mentions;
      if(user_mentions ~= nil and #user_mentions > 0) then
        for j = 1, #user_mentions, 1 do
          local item = user_mentions[j];

          local mention = {};
          mention.name = item.name;
          mention.screen_name = item.screen_name;

          table.insert(tweets[i].user_mentions, mention);
        end
      end

      local hashtags = tweet.entities.hashtags;
      if(hashtags ~= nil and #hashtags > 0) then
        for j = 1, #hashtags, 1 do
          local item = hashtags[j];

          table.insert(tweets[i].hashtags, item.text);
        end
      end

      local urls = tweet.entities.urls;
      if(urls ~= nil and #urls > 0) then
        for j = 1, #urls, 1 do
          local item = urls[j];

          local url = {};
          url.url = item.url;
          url.expanded_url = item.expanded_url;

          table.insert(tweets[i].urls, url);
        end
      end
    end

    local createdAt = dateHelper:getTimestamp(tweet.created_at, "EEE MMM dd HH:mm:ss Z yyyy");
    createdAt = dateHelper:getString(createdAt, "yyyy/MM/dd HH:mm:ss");
    tweets[i].created_at = createdAt;

    tweets[i].favorite_count = tweet.favorite_count;
    tweets[i].id = tweet.id_str;
    tweets[i].possibly_sensitive = tweet.possibly_sensitive;
    tweets[i].truncated = tweet.truncated;
    tweets[i].text = tweet.text;

    tweets[i].user = {}
    tweets[i].user.id = tweet.user.id_str;
    tweets[i].user.name = tweet.user.name;
    tweets[i].user.profile_image_url = tweet.user.profile_image_url_https;
    tweets[i].user.screen_name = tweet.user.screen_name;
    tweets[i].user.description = tweet.user.description;
    tweets[i].user.verified = tweet.user.verified;
  end

  local id = "twitter-" .. new("FDLHashHelper"):getRandomUUID();

  local css = ".Twitter { padding: 10px 20px 10px 20px; overflow-y: auto; overflow-x: hidden; height: 100%; position: relative; } .Twitter > .Tweet { padding: 10px; position: relative; } .Twitter > .Tweet:not(:last-child) { border-bottom: _WIDGET_BORDER_COLOR 2px solid; border-bottom-left-radius: 1px; border-bottom-right-radius: 1px; } .Twitter > .Tweet .Left{ position: absolute; } .Twitter > .Tweet.Retweet .Left > .Image{ top: 20px; position: relative; } .Twitter > .Tweet .Right{ position: relative; left: 55px; width: 95%; } .Twitter > .Tweet .Left, .Twitter > .Tweet .Right{ display: inline-block; vertical-align: top; padding-right: 10px; } .Twitter > .Tweet .Right > .User.Retweeted { display: inline-block; height: 20px; } .Twitter > .Tweet .FCOIcon.Retweeted { color: #77b255; display: inline-block; padding-right: 10px; position: absolute; left: -20px; } ";
  local html = "";
  local javascript = "";

  html = html.."<div id=\""..id.."\" class=\"Twitter\">"
  for i = 1, #tweets, 1 do

    local tweet = tweets[i];

    local class = "Tweet";
    if(tweet.possibly_sensitive) then
      class = class .. " Sensitive";
    end
    if(tweet.retweet) then
      class = class .. " Retweet";
    end

    html = html.."<div id=\""..tweet.id.."\" class=\""..class.."\">";

    html = html.."<div class=\"Left\">";
    html = html.."<div class=\"Image\"><img src=\""..tweet.user.profile_image_url.."\" /></div>";
    html = html .. "</div>";

    html = html.."<div class=\"Right\">";

    if(tweet.retweet) then
      html = html.."<div class=\"FCOIcon FCOIcon-FCOIcon1 Retweeted\">&#57473;</div>";
      html = html.."<div class=\"User Retweeted\">"..(translate.string("#__TWITTER_WIDGET_X_RETWEETED", "<a href=\"https://twitter.com/"..tweet.retweetedBy.screen_name.."\">"..tweet.retweetedBy.name.."</a>")).."</div>";
    end

    html = html.."<div class=\"User\"><a href=\"https://twitter.com/"..tweet.user.screen_name.."\">"..tweet.user.name.."</a> @"..tweet.user.screen_name.." - "..tweet.created_at.."</div>";
    html = html .. "<div class=\"Text\"><p>"..getTweetText(tweet).."</p></div>";

    -- Add images in
    if(#tweet.images > 0) then

      html = html.."<div id=\"Images\" class=\"Images\">";

      for i =1, #tweet.images, 1 do
        local image = tweet.images[i];

        html = html .. "<div id=\""..image.url.."\" class=\"Image\">";
        html = html .. "<a target=\"_blank\" href=\""..image.media_url.."\"><img src=\""..image.media_url.."\" width=\""..image.width.."\" height=\""..image.height.."\" /></a>";
        html = html .. "</div>";

      end

      html = html .. "</div>"; -- Ending .Images
    end

    html = html .. "</div>"; -- Ending .Right
    html = html .. "</div>"; -- Ending .Tweet

  end

  html = html .. "</div>";

  local returnContent = new("FDLCustomWidgetHelper"):createGetContentOutput(css, html, javascript);

  return {
    returnCode = "SUCCESSFUL",
    returnType="STRING",
    returnContent=returnContent
  }
end

function create_function(p)

  local utils = new("Utils");

  local apiKey = p.resourceValues.api_key;
  local apiSecret = p.resourceValues.api_secret;
  
  if(apiSecret ~= nil and apiSecret == "**************************************************") then
    -- This is a create simular call, we need to get the apiSecret from provider data when the key is the same
    apiSecret = nil;
    
    local searchFilter = new("SearchFilter");
    searchFilter:getFilterConditions():add(utils:createFilterCondition("providerType","IS_EQUAL_TO",p.resource:getProviderType()));
    searchFilter:getFilterConditions():add(utils:createFilterCondition("resourceValues.api_key","IS_EQUAL_TO",apiKey));
    searchFilter:getFilterConditions():add(utils:createFilterCondition("resourceUUID","IS_NOT_EQUAL_TO",p.resource:getResourceUUID()));
    
    local adminAPI = new("AdminAPI", "5.0");
    local iterator = adminAPI:runListQuery(searchFilter, nil, "PLUGGABLE_RESOURCE");
    
    if(iterator:hasNext()) then
      local pluggableResource = iterator:next();
      local providerMap = dataStore:getPrivateDataMap(pluggableResource:getResourceUUID());
      if(providerMap ~= nil and providerMap:containsKey("api_secret")) then
        apiSecret = providerMap:get("api_secret");
      end
    end
    
  end
  
  if(apiKey == nil or #apiKey == 0 or apiSecret == nil or #apiSecret == 0) then
    return {
      returnCode = "FAILED",
      errorCode="401",
      errorString=translate.string("#__TWITTER_FEED_ERROR_MISSING_SECRET");
    }
  end
  
  local validateResult = validateAPIKeyAndAPISecret(nil, apiKey, apiSecret);
  if(validateResult.success == false) then
    return validateResult;
  end
  
  local dataStoreMap = new("Map");
  dataStoreMap:put("api_key", apiKey);
  dataStoreMap:put("api_secret", apiSecret);
  dataStore:resetPrivateDataMap(p.resource:getResourceUUID(), dataStoreMap);

  local resourceValues = p.resource:getResourceValues();
  resourceValues:put("api_secret", "**************************************************");

  local widgetHelper = new("FDLCustomWidgetHelper");

  widgetHelper:createIconBlob(p, true);

  return { returnCode = "SUCCESSFUL", returnType="BOOLEAN", returnContent="true" }
end

function delete_function(p)
  local widgetHelper = new("FDLCustomWidgetHelper");

  dataStore:resetPrivateDataMap(p.resource:getResourceUUID(), nil);

  widgetHelper:deleteIconBlob(p, true);

  return { returnCode = "SUCCESSFUL", returnType="BOOLEAN", returnContent="true" }
end

function modify_function(p)

  local providerMap = dataStore:getPrivateDataMap(p.resource:getResourceUUID());
  if(providerMap == nil) then
    providerMap = new("Map");
  end

  local oldAPIKey = providerMap:get("api_key");
  if(oldAPIKey == nil or #oldAPIKey == 0) then
    oldAPIKey = "";
  end
  
  local oldAPISecret = providerMap:get("api_secret");
  if(oldAPISecret == nil or #oldAPISecret == 0) then
    oldAPISecret = "";
  end

  local apiKey = p.resourceValues.api_key;
  if(apiKey == nil or #apiKey == 0) then
    apiKey = oldAPIKey;
  end
  
  local apiSecret = p.resourceValues.api_secret;
  if(apiSecret == nil or #apiSecret == 0 or apiSecret == "**************************************************") then
    -- if apiSecret was omitted, blank, or set as the value set at create and modify, set as old secret value.
    apiSecret = oldAPISecret;
  end

  if((#oldAPIKey == 0 and #apiKey == 0) or (#oldAPISecret == 0 and #apiSecret == 0)) then
    -- No existing or new api values
    return {
      returnCode = "FAILED",
      errorCode="401",
      errorString=translate.string("#__TWITTER_FEED_ERROR_MISSING_SECRET");
    }
  end
  
  if(oldAPIKey ~= apiKey or oldAPISecret ~= apiSecret) then
    -- Need to check the new values are valid and update datastore.
    local validateResult = validateAPIKeyAndAPISecret(nil, apiKey, apiSecret);
    if(validateResult.success == false) then
      return validateResult;
    end
    
    providerMap:put("api_key", apiKey);
    providerMap:put("api_secret", apiSecret);
    dataStore:resetPrivateDataMap(p.resource:getResourceUUID(), providerMap);
  end
  
  local resourceValues = p.resource:getResourceValues();
  resourceValues:put("api_secret", "**************************************************");

  local widgetHelper = new("FDLCustomWidgetHelper");

  widgetHelper:modifyIconBlob(p, true);

  return { returnCode = "SUCCESSFUL", returnType="BOOLEAN", returnContent="true" }
end

function advertise_function(p)
  return { returnCode = "SUCCESSFUL", returnType="BOOLEAN", returnContent="true" }
end

-- Helper Functions --

function validateAPIKeyAndAPISecret(connection, apiKey, apiSecret)

  local hashHelper = new("FDLHashHelper");

  if(connection == nil) then
    local simplehttp = new("simplehttp");
    connection=simplehttp:newConnection({ enable_cookie=true, ssl_verify=true })
  end
  
  local headers = {}
  headers["Content-Type"] = "application/x-www-form-urlencoded;charset=UTF-8";
  headers["Authorization"] = "Basic "..hashHelper:toBase64(apiKey..":"..apiSecret);

  local params = "grant_type=client_credentials";
  local apiResult = makeAPICall(connection,"https://api.twitter.com/oauth2/token","POST",params,headers,false);
  if(apiResult.success == false) then
    local response = new("JSON"):decode(apiResult.response);
    if(response.errors ~= nil and #response.errors > 0) then
      return {
        success=false,
        returnCode = "FAILED",
        errorCode=response.errors[1].code,
        errorString=response.errors[1].message
      }
    end
    return {
      success=false,
      returnCode = "FAILED",
      errorCode=apiResult.statusCode,
      errorString=apiResult.response
    }
  end
  
  return apiResult;
end

function makeAPICall(connection, url, method, params, headers, debug)

  if(debug == nil) then
    debug = false;
  end

  local success=false;
  local statusCode="";
  local response="";

  connection:setURL(url);
  if(headers ~= nil) then
    connection:clearRequestHeaders();
    connection:setRequestHeaders(headers);
  end

  local responseHeaders=nil;

  if(debug) then
    local syslog = new("syslog")
    syslog.openlog("TWITTER_WIDGET", syslog.LOG_ODELAY + syslog.LOG_PID);
    syslog.syslog("LOG_INFO", "Make API Call Request");
    syslog.syslog("LOG_INFO", "Method : " .. method);
    syslog.syslog("LOG_INFO", "URL : " .. url);
    if(type(params)=="table") then
      syslog.syslog("LOG_INFO", "Params : " .. new("JSON"):encode(params));
    else
      syslog.syslog("LOG_INFO","Params : " .. params);
    end
    syslog.syslog("LOG_INFO", "Headers");
    for k, v in pairs(headers) do
      syslog.syslog("LOG_INFO", k .." : " .. v);
    end
    syslog.closelog();
  end

  local apiFunction=function(value) response=response .. tostring(value); return true; end

  if(method == "GET") then
    if(connection:get(apiFunction)) then
      success=true;
      statusCode=connection:getHTTPStatusCode();
      responseHeaders=connection:getResponseHeaders();
    else
      success=false;
      statusCode, response=connection:getLastError();
      responseHeaders=connection:getResponseHeaders();
    end
  elseif(method == "DELETE") then
    if(connection:delete(apiFunction)) then
      success=true;
      statusCode=connection:getHTTPStatusCode();
      responseHeaders=connection:getResponseHeaders();
    else
      success=false;
      statusCode, response=connection:getLastError();
      responseHeaders=connection:getResponseHeaders();
    end
  elseif(method == "PUT") then
    if(connection:put(params, apiFunction)) then
      success=true;
      statusCode=connection:getHTTPStatusCode();
      responseHeaders=connection:getResponseHeaders();
    else
      success=false;
      statusCode, response=connection:getLastError();
      responseHeaders=connection:getResponseHeaders();
    end
  elseif(method == "POST") then
    if(connection:post(params, apiFunction)) then
      success=true;
      statusCode=connection:getHTTPStatusCode();
      responseHeaders=connection:getResponseHeaders();
    else
      success=false;
      statusCode, response=connection:getLastError();
      responseHeaders=connection:getResponseHeaders();
    end
  end

  if(success and (statusCode < 200 or statusCode >= 300)) then
    success = false;
  end

  if(debug) then
    local syslog = new("syslog")
    syslog.openlog("TWITTER_WIDGET", syslog.LOG_ODELAY + syslog.LOG_PID);
    syslog.syslog("LOG_INFO", "Make API Call Result");
    syslog.syslog("LOG_INFO", "Success : " .. tostring(success));
    syslog.syslog("LOG_INFO", "Status Code : " .. tostring(statusCode));
    syslog.syslog("LOG_INFO", "Response : " .. tostring(response));
    syslog.syslog("LOG_INFO", "Response headers");
    for k, v in pairs(responseHeaders) do
      syslog.syslog("LOG_INFO", tostring(k) .." : " .. tostring(v));
    end
    syslog.closelog();
  end

  return{
    success=success,
    statusCode=statusCode,
    response=response,
    responseHeaders=responseHeaders
  }
end

function getTweetText(tweet)
  local text = tweet.text;

  for i =1, #tweet.urls, 1 do
    local url = tweet.urls[i];

    local expandedURL = string.gsub(url.expanded_url, "%%", "%%%%")
    text = string.gsub(text, url.url, "<a target=\"_blank\" href=\""..expandedURL.."\">"..url.url.."</a>");
  end

  for i = 1, #tweet.hashtags, 1 do
    text = string.gsub(text, "#%f[%w_]"..tweet.hashtags[i].."%f[^%w_]"," <a target=\"_blank\" href=\"https://twitter.com/hashtag/"..tweet.hashtags[i].."?src=hash\">#"..tweet.hashtags[i].."</a>");
  end

  for i = 1, #tweet.user_mentions, 1 do
    text = string.gsub(text, "@%f[%w_]"..tweet.user_mentions[i].screen_name.."%f[^%w_]", "<a target=\"_blank\" href=\"https://twitter.com/"..tweet.user_mentions[i].screen_name.."\">"..tweet.user_mentions[i].name.."</a>");
  end

  -- Remove image links, they will be added later
  for i =1, #tweet.images, 1 do
    text = string.gsub(text, tweet.images[i].url, "");
  end

  return text;
end
