# BeforeIT 3D economy MVP

Open [index.html](index.html) in a browser. The page is self-contained and reads
the committed `data.js` file; it does not run or connect to a simulation.

The view shows all firms from the `consumption-shock-80-quarterly-states-v3`
explanation trace, run `consumption-shock-80-percent-seed-4101` (quarters 0–30).
Each tower keeps a fixed position by persistent firm ID. The indicator selector
changes both its height and color among production (`Y_i`), employment (`N_i`),
profit (`Pi_i`), and outstanding loans (`L_i`). Heights use a fixed square-root
scale for each indicator; profit height uses its absolute value, with color
showing its sign. The side panels show recorded GDP and unemployment among active
workers. Dragging rotates the scene, scrolling zooms, and clicking selects a
firm.

The optional gold markers show the selected indicator's **archived Q+1 plan**:
planned quantity (`Q_s_i`), desired employment (`N_d_i`), expected profit
(`Pi_e_i`), or expected loan balance (`L_e_i`). BeforeIT computes these at the
start of Q+1 and retains them in that quarter's end-of-quarter snapshot. Showing
them beside Q's realized state is a retrospective comparison, not a forecast
available at the end of Q. Quarter 30 has no Q31 marker.

To refresh the bundled data from the archived JLD2 snapshots, run from the
repository root:

```bash
julia --project=. dba-studies/three-dimensional-economy/export_data.jl
```

`export_data.jl` only reads snapshots and writes `data.js`. The source snapshots
are under `dba-studies/machine-learning/explanation-traces/experiments/` and are
ignored by Git. The bundled data lets the viewer run even without those local
snapshots or Julia installed.

Check the bundled data with `node dba-studies/three-dimensional-economy/check_data.mjs`.

Tower positions are an illustrative layout, not geography. Animated changes
interpolate between quarterly observations; they do not reconstruct activity
inside a quarter. The archive has firm states, but no realized firm-to-firm
transaction links, so the view does not draw them.
