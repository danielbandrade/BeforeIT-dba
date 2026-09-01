import BeforeIT as Bit

using Test

@testset "gambling transfers" begin
    @testset "disabled gambling" begin
        model = Bit.Model(
            Bit.AUSTRIA2010Q1.parameters,
            Bit.AUSTRIA2010Q1.initial_conditions,
        )

        income_act = copy(model.w_act.Y_h)
        income_inact = copy(model.w_inact.Y_h)

        stakes_act, stakes_inact, receipts =
            Bit.gambling_transfers(model; income_act, income_inact)

        @test all(iszero, stakes_act)
        @test all(iszero, stakes_inact)
        @test all(iszero, receipts)
    end

    @testset "positive gambling" begin
        parameters = copy(Bit.AUSTRIA2010Q1.parameters)
        initial_conditions = copy(Bit.AUSTRIA2010Q1.initial_conditions)

        parameters["gambling_income_share"] = 0.1
        initial_conditions["gambling_active_worker_ids"] = [1, 2]
        initial_conditions["gambling_inactive_worker_ids"] = [1]
        initial_conditions["gambling_owner_ids"] = [1, 2]

        model = Bit.Model(parameters, initial_conditions)

        income_act = zeros(length(model.w_act))
        income_inact = zeros(length(model.w_inact))
        income_act[1] = 100
        income_act[2] = -50
        income_inact[1] = 40

        income_act_before = copy(income_act)
        income_inact_before = copy(income_inact)

        stakes_act, stakes_inact, receipts =
            Bit.gambling_transfers(model; income_act, income_inact)

        @test stakes_act[1] ≈ 10
        @test iszero(stakes_act[2])
        @test stakes_inact[1] ≈ 4
        @test receipts[1] ≈ 7
        @test receipts[2] ≈ 7
        @test sum(stakes_act) + sum(stakes_inact) ≈ sum(receipts)
        @test income_act == income_act_before
        @test income_inact == income_inact_before
    end
    @testset "gambling budgets" begin
        parameters = copy(Bit.AUSTRIA2010Q1.parameters)
        initial_conditions = copy(Bit.AUSTRIA2010Q1.initial_conditions)

        parameters["gambling_income_share"] = 0.1
        initial_conditions["gambling_active_worker_ids"] = [1]
        initial_conditions["gambling_inactive_worker_ids"] = [1]
        initial_conditions["gambling_owner_ids"] = [1, 2]

        model = Bit.Model(parameters, initial_conditions)

        income_act = Bit.households_income_act(model; expected = true)
        income_inact = Bit.households_income_inact(model; expected = true)
        income_firms = Bit.households_income_firms(model; expected = true)
        income_bank = Bit.households_income_bank(model; expected = true)

        stakes_act, stakes_inact, receipts =
            Bit.gambling_transfers(model; income_act, income_inact)

        consumption_act, investment_act = Bit.households_budget_act(model)
        consumption_inact, investment_inact = Bit.households_budget_inact(model)
        consumption_firms, investment_firms = Bit.households_budget_firms(model)
        consumption_bank, investment_bank = Bit.households_budget_bank(model)

        @test consumption_act ≈
            model.prop.psi * (income_act - stakes_act) /
            (1 + model.prop.tau_VAT)

        @test investment_act ≈
            model.prop.psi_H * (income_act - stakes_act) /
            (1 + model.prop.tau_CF)

        @test consumption_inact ≈
            model.prop.psi * (income_inact - stakes_inact) /
            (1 + model.prop.tau_VAT)

        @test investment_inact ≈
            model.prop.psi_H * (income_inact - stakes_inact) /
            (1 + model.prop.tau_CF)

        @test consumption_firms ≈
            model.prop.psi * (income_firms + receipts) /
            (1 + model.prop.tau_VAT)

        @test investment_firms ≈
            model.prop.psi_H * (income_firms + receipts) /
            (1 + model.prop.tau_CF)

        @test consumption_bank ≈
            model.prop.psi * income_bank /
            (1 + model.prop.tau_VAT)

        @test investment_bank ≈
            model.prop.psi_H * income_bank /
            (1 + model.prop.tau_CF)
    end

    @testset "realized gambling transfers" begin
        parameters = copy(Bit.AUSTRIA2010Q1.parameters)
        initial_conditions = copy(Bit.AUSTRIA2010Q1.initial_conditions)

        parameters["gambling_income_share"] = 0.1
        initial_conditions["gambling_active_worker_ids"] = [1]
        initial_conditions["gambling_inactive_worker_ids"] = [1]
        initial_conditions["gambling_owner_ids"] = [1, 2]

        model = Bit.Model(parameters, initial_conditions)

        fill!(model.w_act.Y_h, 0)
        fill!(model.w_inact.Y_h, 0)
        fill!(model.firms.Y_h, 10)

        model.w_act.Y_h[1] = 100
        model.w_inact.Y_h[1] = 40

        total_income_before =
            sum(model.w_act.Y_h) +
            sum(model.w_inact.Y_h) +
            sum(model.firms.Y_h)

        Bit.set_gambling_transfers!(model)

        total_income_after =
            sum(model.w_act.Y_h) +
            sum(model.w_inact.Y_h) +
            sum(model.firms.Y_h)

        @test model.w_act.Y_h[1] ≈ 90
        @test model.w_inact.Y_h[1] ≈ 36
        @test model.firms.Y_h[1] ≈ 17
        @test model.firms.Y_h[2] ≈ 17
        @test model.agg.gambling_volume ≈ 14
        @test total_income_after ≈ total_income_before
    end
    @testset "gambling data collection" begin
        parameters = copy(Bit.AUSTRIA2010Q1.parameters)
        initial_conditions = copy(Bit.AUSTRIA2010Q1.initial_conditions)

        parameters["gambling_income_share"] = 0.1
        initial_conditions["gambling_active_worker_ids"] = [1]
        initial_conditions["gambling_inactive_worker_ids"] = [1]
        initial_conditions["gambling_owner_ids"] = [1]

        model = Bit.Model(parameters, initial_conditions)

        Bit.collect_data!(model)
        Bit.step!(model)
        Bit.collect_data!(model)

        @test model.data.gambling_volume[1] == 0
        @test model.data.gambling_volume[end] ≈ model.agg.gambling_volume
        @test length(model.data.gambling_volume) ==
            length(model.data.collection_time)

        number_of_periods = length(model.data.collection_time)

        @test all(
            field -> length(getfield(model.data, field)) == number_of_periods,
            fieldnames(typeof(model.data)),
        )
    end
    @testset "gambling configuration validation" begin
        function rejects(parameters, initial_conditions)
            try
                Bit.Model(parameters, initial_conditions)
            catch exception
                return exception isa ArgumentError
            end

            return false
        end

        parameters = copy(Bit.AUSTRIA2010Q1.parameters)
        initial_conditions = copy(Bit.AUSTRIA2010Q1.initial_conditions)

        parameters["gambling_income_share"] = 0.1
        initial_conditions["gambling_active_worker_ids"] = [1]
        initial_conditions["gambling_inactive_worker_ids"] = [1]
        initial_conditions["gambling_owner_ids"] = [1]

        bad_parameters = copy(parameters)
        bad_parameters["gambling_income_share"] = -0.1
        @test rejects(bad_parameters, initial_conditions)

        bad_parameters = copy(parameters)
        bad_parameters["gambling_income_share"] = 1.1
        @test rejects(bad_parameters, initial_conditions)

        bad_initial_conditions = copy(initial_conditions)
        bad_initial_conditions["gambling_active_worker_ids"] = Int[]
        bad_initial_conditions["gambling_inactive_worker_ids"] = Int[]
        @test rejects(parameters, bad_initial_conditions)

        bad_initial_conditions = copy(initial_conditions)
        bad_initial_conditions["gambling_owner_ids"] = Int[]
        @test rejects(parameters, bad_initial_conditions)

        bad_initial_conditions = copy(initial_conditions)
        bad_initial_conditions["gambling_active_worker_ids"] = [1, 1]
        @test rejects(parameters, bad_initial_conditions)

        bad_initial_conditions = copy(initial_conditions)
        bad_initial_conditions["gambling_inactive_worker_ids"] = [1, 1]
        @test rejects(parameters, bad_initial_conditions)

        bad_initial_conditions = copy(initial_conditions)
        bad_initial_conditions["gambling_owner_ids"] = [1, 1]
        @test rejects(parameters, bad_initial_conditions)

        number_of_firms = sum(parameters["I_s"])
        number_of_active_workers =
            parameters["H_act"] - number_of_firms - 1

        bad_initial_conditions = copy(initial_conditions)
        bad_initial_conditions["gambling_active_worker_ids"] =
            [number_of_active_workers + 1]
        @test rejects(parameters, bad_initial_conditions)

        bad_initial_conditions = copy(initial_conditions)
        bad_initial_conditions["gambling_inactive_worker_ids"] =
            [parameters["H_inact"] + 1]
        @test rejects(parameters, bad_initial_conditions)

        bad_initial_conditions = copy(initial_conditions)
        bad_initial_conditions["gambling_owner_ids"] = [number_of_firms + 1]
        @test rejects(parameters, bad_initial_conditions)

        old_model = Bit.Model(
            Bit.AUSTRIA2010Q1.parameters,
            Bit.AUSTRIA2010Q1.initial_conditions,
        )

        @test old_model.prop.gambling_income_share == 0
        @test isempty(old_model.prop.gambling_active_worker_ids)
        @test isempty(old_model.prop.gambling_inactive_worker_ids)
        @test isempty(old_model.prop.gambling_owner_ids)
    end
end
