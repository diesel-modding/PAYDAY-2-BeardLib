PrePlanningModule = PrePlanningModule or BeardLib:ModuleClass("PrePlanning", ItemModuleBase)
PrePlanningModule.required_params = {}

function PrePlanningModule:init(...)
    self.clean_table = table.add(clone(self.clean_table), {
        {param = "locations", action = function(tbl)
                for _, v in pairs(tbl) do
                    if type(v) == "table" then
                        table.remove_condition(v, function(_v)
                            return _v._meta == "default_plans" or _v._meta == "start_location"
                        end)
                    end
                end
        end}
    })
    return PrePlanningModule.super.init(self, ...)
end

function PrePlanningModule:RegisterHook()
    if tweak_data and tweak_data.preplanning then
        self:AddPrePlanningDataToTweak(tweak_data.preplanning)
    else
        Hooks:PostHook(PrePlanningTweakData, "init", self._mod.Name .. "AddPrePlanningData", ClassClbk(self, "AddPrePlanningDataToTweak"))
    end
end

function PrePlanningModule:AddPrePlanningDataToTweak(pp_self)
    if self._config.locations then
        for _, data in ipairs(self._config.locations) do
            if data._meta == "location" then
                if pp_self.locations[data.id] then
                    self:Err("Pre Planning Location with id '%s' already exists!", data.id)
                else
                    data.default_plans = data.default_plans or {}
                    BeardLib.Utils:RemoveMetas(data, false)
                    for i, sub in ipairs(data) do
                        BeardLib.Utils:RemoveAllNumberIndexes(data[i], true)
                    end
                    pp_self.locations[data.id] = data
                end
            end
        end
    end

    if self._config.categories then
        for _, data in ipairs(self._config.categories) do
            if data._meta == "category" then
                if pp_self.categories[data.id] then
                    self:Err("Pre Planning Category with id '%s' already exists!", data.id)
                else
                    BeardLib.Utils:RemoveMetas(data, true)
                    data.name_id = data.name_id or ("menu_pp_cat_"..data.id)
                    data.desc_id = data.desc_id or data.name_id.."_desc"
                    pp_self.categories[data.id] = data
                end
            end
        end
    end

    if self._config.types then
        for _, data in ipairs(self._config.types) do
            if data._meta == "type" then
                if pp_self.types[data.id] then
                    self:Err("Pre Planning Type with id '%s' already exists!", data.id)
                else
                    BeardLib.Utils:RemoveMetas(data, true)
                    data.name_id = data.name_id or ("menu_pp_"..data.id)
                    data.desc_id = data.desc_id or data.name_id.."_desc"
                    pp_self.types[data.id] = data
                end
            end
        end
    end

    if self._config.plans then
        for id, data in ipairs(self._config.plans) do
            if data._meta == "plan" then
                if pp_self.plans[data.id] then
                    self:Err("Pre Planning Plan with id '%s' already exists!", data.id)
                else
                    local plan = {category = data.category or data.id}
                    pp_self.plans[data.id] = plan
                end
            end
        end
    end
end