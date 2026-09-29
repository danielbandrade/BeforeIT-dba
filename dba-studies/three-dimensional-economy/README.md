# BeforeIT 3D economy MVP

Open [index.html](index.html) for the firm landscape or [market.html](market.html)
for the goods market. Both pages read the committed `data.js` file; neither runs
or connects to a simulation.

The experiment selector includes all 11 complete quarterly snapshot runs currently
available in `explanation-traces/experiments`: the consumption shock and credit
constraint scenarios, including their different seeds and horizons. It defaults
to `consumption-shock-80-quarterly-states-v3`, seed 4101. The older
`credit-constraint-explanation-v1` files use a different trace format and are
not included.
Each tower keeps a fixed position by persistent firm ID. The indicator selector
changes both its height and color among production (`Y_i`), employment (`N_i`),
profit (`Pi_i`), and outstanding loans (`L_i`). Heights use a fixed square-root
scale for each indicator; profit height uses its absolute value, with color
showing its sign. The side panels show recorded GDP and unemployment among active
workers. Dragging rotates the scene, scrolling zooms, and clicking selects a
firm. The selected firm shows its sector's NACE code and description from
[`sector-cheatsheet.md`](../model-mechanics/sector-cheatsheet.md).

The optional gold markers show the selected indicator's **archived Q+1 plan**:
planned quantity (`Q_s_i`), desired employment (`N_d_i`), expected profit
(`Pi_e_i`), or expected loan balance (`L_e_i`). BeforeIT computes these at the
start of Q+1 and retains them in that quarter's end-of-quarter snapshot. Showing
them beside Q's realized state is a retrospective comparison, not a forecast
available at the end of Q. The final quarter of each run has no following marker.

The goods-market view lets you choose a run, quarter, and product sector. It
shows archived seller prices, domestic sales and ending inventory, import
supply and sales. Domestic starting supply is reconstructed as sales plus
ending inventory. The seller draw chance uses the model's price and supply
weight formula. The example buyer uses the same weighted draw and stock rule
one match at a time. It is illustrative: the snapshots do not retain actual
buyer–seller links, and firm input purchases occur before retail matching.

To refresh the bundled data from the archived JLD2 snapshots, run from the
repository root:

```bash
julia --project=. dba-studies/three-dimensional-economy/export_data.jl
```

`export_data.jl` discovers successful quarterly snapshot runs and writes `data.js`.
It only reads snapshots. The source snapshots
are under `dba-studies/machine-learning/explanation-traces/experiments/` and are
ignored by Git. The bundled data lets the viewer run even without those local
snapshots or Julia installed.

Check the bundled data and market controls with
`node dba-studies/three-dimensional-economy/check_data.mjs` and
`node dba-studies/three-dimensional-economy/check_market.mjs`.

Tower positions are an illustrative layout, not geography. Animated changes
interpolate between quarterly observations; they do not reconstruct activity
inside a quarter. The archive has firm states, but no realized firm-to-firm
transaction links, so the view does not draw them.
