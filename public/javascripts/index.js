document.documentElement.className = "yui-pe";

YAHOO.util.Event.addListener(window, "load", function() {

    var expansionFormatter = function(el, oRecord, oColumn, oData) {
        var cell_element = el.parentNode;
        if ( oData) {
            YAHOO.util.Dom.addClass( cell_element,
                                     "yui-dt-expandablerow-trigger" );
        }
    };

    var instanceColumns = [
        { label: "Expand", key: "hostname", sortable: true, formatter: expansionFormatter },
        { key: "hostname", label: "Hostname", sortable: true },
        { key: "id", label: "Instance ID", sortable: true },
        { key: "type", label: "Instance Type", sortable: true },
        { key: "active", label: "Active", sortable: true }
    ];

    this.instanceDS = new YAHOO.util.XHRDataSource("/api/getInstances");
    this.instanceDS.responseType = YAHOO.util.XHRDataSource.TYPE_XML;
    this.instanceDS.responseSchema = {
        resultNode: "instance",
        fields: ["id", "type", "active", "hostname"]
    };

    var loadInstanceDetails = function(opt) {
        this.row = opt;
        this.instance = opt.data.getData('id');

/*
        var callback = {
            success : function(o) {
                return 'grapey mc shit from shitterton';
            },
            argument : this.row
        }
        YAHOO.util.Connect.asyncRequest('GET', '/api/getInstanceDetailPane/' + this.instance, callback);
*/
        return 'yo man, wtf';
    };

    this.tableDeferred = new YAHOO.widget.RowExpansionDataTable("instanceTable", instanceColumns, this.instanceDS,
                                                                {rowExpansionTemplate: loadInstanceDetails}
                                                               );

    this.tableDeferred.subscribe('cellClickEvent', this.tableDeferred.onEventToggleRowExpansion );

    var handleLaunch = function() {
        this.submit();
    }

    var handleCancel = function() {
        this.cancel();
    }

    var handleAddCloud = function () {
        this.submit();
    }

    var dialogAddInstance = new YAHOO.widget.Dialog("dialogAddInstance",
        { width: "30em",
        fixedcenter : true,
        visible : false,
        constraintoviewport: true,
        buttons: [ { text:"Launch", handler:handleLaunch, isDefault: true },
        { text:"Cancel", handler:handleCancel }]
        });

    var dialogAddCloud = new YAHOO.widget.Dialog("dialogAddCloud",
        { width: "45em",
        fixedcenter: true,
        visible : false,
        constraintoviewport: true,
        buttons: [ { text:"Add Cloud", handler:handleAddCloud, isDefault: true },
        { text : "Cancel", handler: handleCancel }]
        });

    dialogAddCloud.validate = function () {
        var data = this.getData();
        var table = prettyPrint(data);
        document.body.appendChild(table);
        if (data['cloud[name]'] == '') {
            alert("Name is required.");
            return false;
        }
        if (data['cloud[api_url]'] == '') {
            alert("API URL is required.");
            return false;
        }
        if (data['cloud[query_key]'] == '') {
            alert("API Query Key is required.");
            return false;
        }
        if (data['cloud[query_key_id]'] == '') {
            alert("API Query Key ID is required.");
            return false;
        }
        return true;
    };

    var instanceContextMenu = new YAHOO.widget.ContextMenu("instanceContextMenu",
        { trigger:this.tableDeferred.getTbodyEl()});

    var onInstanceContextMenuClick = function(p_sType, p_aArgs, p_myDataTable) {
        confirm("YEEEHAW A CLICK");
    };

    instanceContextMenu.addItem("Terminate instance");
    instanceContextMenu.addItem("Stop instance");
    instanceContextMenu.addItem("Start instance");

    instanceContextMenu.render("instanceTable");
    instanceContextMenu.clickEvent.subscribe(onInstanceContextMenuClick, this.tableDeferred);

    var tabView = new YAHOO.widget.TabView('merlin');
    YAHOO.util.Dom.removeClass("dialogAddInstance", "yui-pe-content");
    YAHOO.util.Dom.removeClass("dialogAddCloud", "yui-pe-content");

    dialogAddInstance.render();
    YAHOO.util.Event.addListener('addInstance', "click", dialogAddInstance.show, dialogAddInstance, true);

    dialogAddCloud.render();
    YAHOO.util.Event.addListener('addCloud', "click", dialogAddCloud.show, dialogAddCloud, true);
});

