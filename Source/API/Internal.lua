local Auctionary = Auctionary

function Auctionary.API.ComposeError(callerID, message)
  error(
    "Contact the maintainer of " .. callerID ..
    " to resolve this problem. Details: " .. message
  )
end

-- TODO: Maintain authorization keys for add-ons to prevent false callerIDs
function Auctionary.API.InternalVerifyID(callerID)
  if type(callerID) ~= "string" or callerID == "" then
    error("Invalid callerID. Use the name of your add-on.")
  end
end
