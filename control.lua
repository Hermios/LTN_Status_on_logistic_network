require "__Hermios_Framework__.control-libs"
require "constants"
local list_events_signals={
    [signal_dispatcher_no_train_found]="on_dispatcher_no_train_found",
    [signal_provider_missing_cargo]="on_provider_missing_cargo",
    [signal_provider_unscheduled_cargo]="on_provider_unscheduled_cargo",
    [signal_requester_unscheduled_cargo]="on_requester_unscheduled_cargo"
}

local function get_ltn_io(ltn,is_input)
    return ltn.surface.find_entities_filtered{name="logistic-train-stop-"..(is_input and "input" or "output"),position=ltn.position,radius=1}[1]
end

local function add_signal_to_output(ltn,s)
    local output=get_ltn_io(ltn)
    params=output.get_or_create_control_behavior().parameters
    --find index
    local i=1
    while params[i] and params[i].signal.name and params[i].signal.name~=s do
        i=i+1
    end
    if not params[i] then
        return
    end
    output.get_or_create_control_behavior().set_signal(
        i,
        {
            count=1,
            signal={type="virtual",name=s}
        }
    )
end

local function register_error_events()
    for signal,event in pairs(list_events_signals) do
        script.on_event(
            remote.call("logistic-train-network", event),
            function(e)
                if e.station then --requester/provider station
                    add_signal_to_output(e.station,signal)
                elseif e.network_id then --depot station
                    for _,ltn in pairs(game.get_surface(1).find_entities_filtered{name="logistic-train-stop"}) do
                        local network_id=get_ltn_io(ltn,true).get_merged_signal{type="virtual",name="ltn-network-id"}
                        local is_depot=get_ltn_io(ltn,true).get_merged_signal{type="virtual",name="ltn-depot"}>0
                        network_id=network_id>0 and network_id or -1
                        if is_depot and network_id==e.network_id  then
                            add_signal_to_output(ltn,signal)
                        end
                    end
                end
            end
        )
    end
end

local function register_all_events()
    script.on_event(
        remote.call("logistic-train-network", "on_dispatcher_updated"),
        function()
            for _,ltn_stop_output in pairs(game.get_surface(1).find_entities_filtered{name="logistic-train-stop-output"}) do
                local params=ltn_stop_output.get_or_create_control_behavior().parameters
                for i,parameter in pairs(params) do
                    if list_events_signals[parameter.signal.name] then
                        parameter[i]=nil
                    end
                end
                ltn_stop_output.get_control_behavior().parameters=params
            end
        end
    )
    register_error_events()
end
table.insert(list_events.on_init,register_all_events)
table.insert(list_events.on_load,register_all_events)