var gOkButton, gNumberScrollArea, gNumberScrollbar, gErrorScrollArea, gErrorScrollbar;
var gDoneButton, gInfoButton;
var mobiles;

var theMessage;
var theNumber;

var fShowMessage = function() {
    setHeader("Type Message");
    showContentContainer("messagePanel");

    verifyMessage();

    document.getElementById("message").focus();

    fNext = fShowAddressBook;
};

var fShowAddressBook = function() {
    theMessage = getMessage();
    if (!theMessage) return;

    setHeader("Recipient");
    showContentContainer("numberPanel");
    enableOkButton(false);

    refreshAddressBook();

    fNext = fShowProgress;
};

var fShowProgress = function() {
    theNumber = getSelectedNumber();
    if (!theNumber) return;

    setHeader("Status");
    showContent("Sending Message...");

    enableOkButton(false);
    fNext = fShowMessage;

    sendMessage();
};

var fNext = fShowAddressBook;

window.onload = init;

function init()
{
    setupAppleControls();

    clearMessageText();
    fShowMessage();

    document.getElementById("message").onkeyup = verifyMessage;
    document.getElementById("numberSearchGhost").onclick = focusNumberSearch;
    document.getElementById("numberSearch").onblur = blurNumberSearch;
    document.getElementById("numberSearch").onkeyup = numberSearch;
    document.getElementById("cancel").onclick = cancel;
}

function setupAppleControls()
{
    gNumberScrollbar = new AppleVerticalScrollbar(
        document.getElementById("numberScrollbar")
    );
 
    gNumberScrollArea = new AppleScrollArea(
        document.getElementById("numberScrollArea")
    );
 
    gNumberScrollArea.addScrollbar(gNumberScrollbar);

    gErrorScrollbar = new AppleVerticalScrollbar(
        document.getElementById("errorScrollbar")
    );
 
    gErrorScrollArea = new AppleScrollArea(
        document.getElementById("errorScrollArea")
    );
 
    gErrorScrollArea.addScrollbar(gErrorScrollbar);

    gOkButton = new AppleGlassButton(document.getElementById("ok"), "OK", buttonClicked);
    gDoneButton = new AppleGlassButton(document.getElementById("done"), "OK", hidePrefs);
    gInfoButton = new AppleInfoButton(document.getElementById("infoButton"), document.getElementById("front"), "white", "white", showPrefs);

    gDoneButton.textElement.style.color = 'Black';
}

function refreshAddressBook()
{
    document.getElementById("numberSearch").value = "";
    blurNumberSearch();

    if (window.AddressBookPlugIn)
    {
        var rawMobiles = AddressBookPlugIn.peopleWithMobiles();

        if (!rawMobiles || rawMobiles.length==0)
        {
            showError("No contacts with mobiles found in Address Book.");
        }
        else
        {
            var container = document.getElementById("numberScrollArea");

            while (container.lastChild)
            {
                container.removeChild(container.lastChild);
            }

            mobiles = sortMobiles(rawMobiles);

            for (var i=0; i<mobiles.length; i++)
            {
                /*
                var first = mobiles[i][0];
                var second = mobiles[i][1];
                var mobile = mobiles[i][2];
                var id = mobiles[i][3];
                */

                if (mobiles[i].name && mobiles[i].number)
                {
                    var div = document.createElement("div");
                    div.id = "mobileEntry" + i;
                    div.className = "entry";

                    div.onclick = selectEntry;

                    var header = document.createElement("h2");
                    header.appendChild(document.createTextNode(mobiles[i].name));

                    div.appendChild(header);
                    div.appendChild(document.createTextNode(mobiles[i].number));

                    container.appendChild(div);
                }
            }

            var div0 = document.createElement("div");
            div0.id = "mobileEntryFree";
            div0.className = "free_entry";
            var header0 = document.createElement("h2");
            header0.appendChild(document.createTextNode("Enter Number:"));
            div0.appendChild(header0);
            var input = document.createElement("input");
            input.id = "freeEntryInput";
            input.onkeyup = function() { enableOkButton(input.value != ''); };
            div0.appendChild(input);
            container.appendChild(div0);

            gNumberScrollArea.refresh();
        }
    }
    else
    {
        showError("No address book plugin found.");
    }
}

function buttonClicked()
{
    if (!gOkButton.enabled) return;

    fNext();
}

function setHeader(text)
{
    document.getElementById("header").firstChild.nodeValue = text;
}

function showContentContainer(id)
{
    document.getElementById("messagePanel").style.display = 'none';
    document.getElementById("numberPanel").style.display = 'none';
    document.getElementById("infoPanel").style.display = 'none';

    document.getElementById(id).style.display = 'inline';
}

function showContent(text)
{
    showContentContainer("infoPanel");
    document.getElementById("errorScrollArea").firstChild.nodeValue = text;
    gErrorScrollArea.refresh();
}

function verifyMessage()
{
    var msg = getMessage();
    var enabled = true;

    if (!msg || msg.length == 0) // || msg.length > 160)
    {
        enabled = false;
        document.getElementById("charsUsed").firstChild.nodeValue = ' ';
    }
    else
    {
        document.getElementById("charsUsed").firstChild.nodeValue = msg.length;
    }

    enableOkButton(enabled);
}

function clearMessageText()
{
    document.getElementById("message").value = "";
    verifyMessage();
}

function enableOkButton(val)
{
    gOkButton.setEnabled(val);
    gOkButton.textElement.style.color = (val ? 'Black' : 'Gray');
}

function showError(text)
{
    setHeader("Error");
    showContent(text);
    enableOkButton(true);
    fNext = fShowMessage;
}

function selectEntry(e)
{
    var id = e.currentTarget.id;
    var entries = document.getElementById("numberScrollArea").getElementsByTagName("div");

    for (var i=0; i<entries.length; i++)
    {
        if (entries[i].id == id)
        {
            entries[i].className = 'entry_selected';
            enableOkButton(true);
        }
        else if (entries[i].id != 'mobileEntryFree')
        {
            entries[i].className = 'entry';
        }
    }
}

function getMessage()
{
    return document.getElementById("message").value;
}

function getSelectedNumber()
{
    var entries = document.getElementById("numberScrollArea").getElementsByTagName("div");

    for (var i=0; i<entries.length; i++)
    {
        if (entries[i].className == 'entry_selected')
        {
            return mobiles[i].number;
        }
    } 

    var freeEntry = document.getElementById("freeEntryInput");

    if (freeEntry.value != '')
    {
        return freeEntry.value;
    }

    return null;
}

function sendMessage()
{
    if (!theNumber || !theMessage) return;

    //theNumber = "+34636685421";
    
    var username = widget.preferenceForKey("username");
    var password = widget.preferenceForKey("password");
    var provider = widget.preferenceForKey("provider");

    if (!username || !password || !provider)
    {
        showError("No login details. Please provide these in preferences.");
        return;
    }

    theMessage = escapeShell(theMessage);
    username = escapeShell(username);
    password = escapeShell(password);

    var command = "cd o2sms && perl -I lib o2sms.pl --embedded " 
        + "-C \"" + provider + "\" --no-reuse "
        + " -u \"" + username + "\" -p '" + password 
        + "' -m \"" + theMessage + "\" \"" + theNumber + "\"";

    alert(command);

    try
    {
        var handle = widget.system(command, sendMessageHandler);
    }
    catch (e)
    {
        showError("Message Sending Failed: is o2sms installed?");

        throw(e);
    }
}

function sendMessageHandler(obj)
{
   if (obj.status == 0)
   {
        showContent("Message Sent");
        enableOkButton(true);
   }
   else
   {
        showError("Message Sending Failed: " + obj.errorString);
   }
}

function escapeShell(str)
{
    return str.replace(/"/g, '\\"');
}

function showPrefs()
{
    if (window.widget && widget.preferenceForKey("username"))
    {
        document.getElementById("username").value = widget.preferenceForKey("username");
        document.getElementById("password").value = widget.preferenceForKey("password");
        document.getElementById("provider").value = widget.preferenceForKey("provider");
    }

    var front = document.getElementById("front");
    var back = document.getElementById("back");
 
 /*
    if (window.widget)
        widget.prepareForTransition("ToBack");
        */
 
    front.style.display="none";
    back.style.display="block";
 
    /*
    if (window.widget)
        setTimeout ('widget.performTransition();', 0);
        */
}

function hidePrefs()
{
    if (window.widget)
    {
        widget.setPreferenceForKey(document.getElementById("username").value,"username");
        widget.setPreferenceForKey(document.getElementById("password").value,"password");
        widget.setPreferenceForKey(document.getElementById("provider").value,"provider");
    }

    var front = document.getElementById("front");
    var back = document.getElementById("back");
 
    /*
    if (window.widget)
        widget.prepareForTransition("ToFront");
 */
    back.style.display="none";
    front.style.display="block";
 /*
    if (window.widget)
        setTimeout ('widget.performTransition();', 0);
        */
}


function numberSearch()
{
    var search = document.getElementById("numberSearch").value.toLowerCase();
    var entries = document.getElementById("numberScrollArea").getElementsByTagName("div");

    for (var i=0; i<entries.length; i++)
    {
        if (entries[i].id == 'mobileEntryFree') 
        {
            if (search == '')
            {
                entries[i].style.display = 'block';
            }
            else
            {
                entries[i].style.display = 'none';
            }
        }
        else
        {
            var name = mobiles[i].name;

            if (search == '' || name.substr(0, search.length).toLowerCase() == search)
            {
                entries[i].style.display = 'block';
            }
            else
            {
                entries[i].style.display = 'none';
            }
        }
    }

    gNumberScrollArea.refresh();
}

function sortMobiles(rawMobiles)
{
    mobiles = new Array();

    for (var i=0; i<rawMobiles.length; i++)
    {
        var name = rawMobiles[i][0] + " " + rawMobiles[i][1];
        var number = rawMobiles[i][2];

        mobiles.push({name: name, number: number});
    }
    
    mobiles.sort(mobileSortFunction);

    return mobiles;
}

function mobileSortFunction(a,b)
{
    return (a.name > b.name ? 1 : -1);
}

function cancel()
{
    fShowMessage();
}
 
function focusNumberSearch()
{
    document.getElementById("numberSearchGhost").style.display = 'none';
    document.getElementById("numberSearch").focus();
}

function blurNumberSearch()
{
    if (document.getElementById("numberSearch").value == "")
    {
        document.getElementById("numberSearchGhost").style.display = 'block';
    }
    else
    {
        document.getElementById("numberSearchGhost").style.display = 'none';
    }
}
