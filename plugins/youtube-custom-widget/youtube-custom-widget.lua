--[[
YouTube Custom Widget Provider
© 2015 Flexiant Ltd

This FDL code block defines a custom widget pluggable resource provider that will allow 
the creation of widgets containing embedded YouTube videos

{"FDLINFO":{"NAME":"YouTube Custom Widget","VERSION":"1.0.0"}}
]]

function register()
  return { "youtube_widget_provider" }
end

function youtube_widget_provider()
  local widgetHelper = new("FDLCustomWidgetHelper");
  
  local videoIdParam = { 
    key="video_id", 
    name="#__YOUTUBE_EMBEDDED_VIDEO_ID_NAME", 
    description="#__YOUTUBE_EMBEDDED_VIDEO_ID_DESCRIPTION", 
    required=true 
  }
  
  local configurableList = {};
  table.insert(configurableList, widgetHelper:getResourceDescriptionValueDefinition(true));
  table.insert(configurableList, widgetHelper:getResourceIconValueDefinition(true));
  table.insert(configurableList, videoIdParam);

  local actionFunctions = {};
  table.insert(actionFunctions, widgetHelper:getContentActionDefinition("get_content_function", {"BE", "CUSTOMER"}, nil, true));


  return {
    api="PLUGGABLE_PROVIDER",
    version=1,
    ref="youtube_widget_provider",
    name="#__YOUTUBE_EMBEDDED_VIDEO_NAME",
    description="#__YOUTUBE_EMBEDDED_VIDEO_DESCRIPTION",
    providerType="YOUTUBE_EMBEDDED_VIDEO",
    providerGroup="SKYLINE_CUSTOM_WIDGET",
    providerIcon="FONT_ICON_IMAC",
    createFunction={executionFunction="widget_create_function", invocationLevel={"BE"}},
    deleteFunction={executionFunction="widget_delete_function", invocationLevel={"BE"}},
    modifyFunction={executionFunction="widget_modify_function", invocationLevel={"BE"}},
    advertiseFunction={executionFunction="widget_advertise_function", invocationLevel={"BE"}},
    productComponentTypes={
      {
        name="#__YOUTUBE_EMBEDDED_VIDEO_PCT_NAME",
        referenceField="YOUTUBE_EMBEDDED_VIDEO_PCT",
        optional=false,
        configurableList=configurableList
      }
    },
    actionFunctions=actionFunctions
  }
end

function get_content_function(p)

  local videoId = p.resourceValues.video_id;
  
  local id = "youtube-" .. new("FDLHashHelper"):getRandomUUID();
  
  local aspectRatio = (16/9);
  
  local css = "#"..id.."{position:absolute;top:10px;left:20px;right:20px;bottom:10px;margin:auto;}#"..id..">iframe{width:100%;height:100%;}";
  local html = "<div id=\""..id.."\" class=\"youtube "..videoId.."\"><iframe src=\"https://www.youtube.com/embed/"..videoId.."?rel=0\" frameborder=\"0\" allowfullscreen></iframe></div>";
  local javascript = "var container=$(\"#"..id.."\"),width=$(container).width(),height=$(container).height(),ar="..aspectRatio..";(height*ar)>width?$(container).height(width/ar):$(container).width(height*ar);";

  local returnContent = new("FDLCustomWidgetHelper"):createGetContentOutput(css, html, javascript);

  return { returnCode = "SUCCESSFUL", returnType="STRING", returnContent=returnContent }
end

function widget_create_function(p)
  local widgetHelper = new("FDLCustomWidgetHelper");
  
  widgetHelper:createIconBlob(p, true);

  return { returnCode = "SUCCESSFUL", returnType="BOOLEAN", returnContent="true" }
end

function widget_delete_function(p)
  local widgetHelper = new("FDLCustomWidgetHelper");
  
  widgetHelper:deleteIconBlob(p, false);

  return { returnCode = "SUCCESSFUL", returnType="BOOLEAN", returnContent="true" }
end

function widget_modify_function(p)
  local widgetHelper = new("FDLCustomWidgetHelper");
  
  widgetHelper:modifyIconBlob(p, true);

  return { returnCode = "SUCCESSFUL", returnType="BOOLEAN", returnContent="true" }
end

function widget_advertise_function(p)
  return { returnCode = "SUCCESSFUL", returnType="BOOLEAN", returnContent="true" }
end