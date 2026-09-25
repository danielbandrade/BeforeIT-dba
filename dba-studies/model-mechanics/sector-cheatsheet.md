# BeforeIT sector cheatsheet

`base.firms.G_i` identifies each firm's sector using the Eurostat/NACE A\*64
ordering. BeforeIT models sectors `1` through `62`; A\*64 sectors `T` and `U`
are excluded.

## Quick grouping

| `G_i` range | NACE section | Broad group |
|---:|---|---|
| 1–3 | A | Agriculture, forestry and fishing |
| 4 | B | Mining and quarrying |
| 5–23 | C | Manufacturing |
| 24 | D | Energy |
| 25–26 | E | Water, sewerage and waste |
| 27 | F | Construction |
| 28–30 | G | Wholesale and retail trade |
| 31–35 | H | Transport and storage |
| 36 | I | Accommodation and food services |
| 37–40 | J | Information and communication |
| 41–43 | K | Finance and insurance |
| 44 | L | Real estate |
| 45–49 | M | Professional, scientific and technical services |
| 50–53 | N | Administrative and support services |
| 54 | O | Public administration and defence |
| 55 | P | Education |
| 56–57 | Q | Health and social work |
| 58–59 | R | Arts, entertainment and recreation |
| 60–62 | S | Other services |

## Complete mapping

| `G_i` | NACE | Sector |
|---:|---|---|
| 1 | A01 | Crop and animal production; hunting |
| 2 | A02 | Forestry and logging |
| 3 | A03 | Fishing and aquaculture |
| 4 | B05–B09 | Mining and quarrying |
| 5 | C10–C12 | Food products, beverages and tobacco |
| 6 | C13–C15 | Textiles, clothing and leather |
| 7 | C16 | Wood and cork products |
| 8 | C17 | Paper and paper products |
| 9 | C18 | Printing and reproduction of recorded media |
| 10 | C19 | Coke and refined petroleum |
| 11 | C20 | Chemicals and chemical products |
| 12 | C21 | Pharmaceuticals |
| 13 | C22 | Rubber and plastic products |
| 14 | C23 | Other non-metallic mineral products |
| 15 | C24 | Basic metals |
| 16 | C25 | Fabricated metal products |
| 17 | C26 | Computers, electronic and optical products |
| 18 | C27 | Electrical equipment |
| 19 | C28 | Machinery and equipment |
| 20 | C29 | Motor vehicles and trailers |
| 21 | C30 | Other transport equipment |
| 22 | C31–C32 | Furniture and other manufacturing |
| 23 | C33 | Repair and installation of machinery |
| 24 | D35 | Electricity, gas, steam and air conditioning |
| 25 | E36 | Water collection, treatment and supply |
| 26 | E37–E39 | Sewerage, waste management and remediation |
| 27 | F41–F43 | Construction |
| 28 | G45 | Motor-vehicle trade and repair |
| 29 | G46 | Wholesale trade |
| 30 | G47 | Retail trade |
| 31 | H49 | Land transport and pipelines |
| 32 | H50 | Water transport |
| 33 | H51 | Air transport |
| 34 | H52 | Warehousing and transport support |
| 35 | H53 | Postal and courier activities |
| 36 | I55–I56 | Accommodation and food services |
| 37 | J58 | Publishing |
| 38 | J59–J60 | Film, television, music and broadcasting |
| 39 | J61 | Telecommunications |
| 40 | J62–J63 | Computer programming and information services |
| 41 | K64 | Financial services |
| 42 | K65 | Insurance and pension funding |
| 43 | K66 | Auxiliary financial and insurance activities |
| 44 | L68 | Real estate |
| 45 | M69–M70 | Legal, accounting and management consultancy |
| 46 | M71 | Architecture, engineering and technical testing |
| 47 | M72 | Research and development |
| 48 | M73 | Advertising and market research |
| 49 | M74–M75 | Other professional services and veterinary activities |
| 50 | N77 | Rental and leasing |
| 51 | N78 | Employment activities |
| 52 | N79 | Travel agencies and tour operators |
| 53 | N80–N82 | Security, building and administrative support |
| 54 | O84 | Public administration and defence |
| 55 | P85 | Education |
| 56 | Q86 | Human health |
| 57 | Q87–Q88 | Residential care and social work |
| 58 | R90–R92 | Arts, culture and gambling |
| 59 | R93 | Sports and recreation |
| 60 | S94 | Membership organisations |
| 61 | S95 | Repair of computers and household goods |
| 62 | S96 | Other personal services |

## Interpretation notes

- `G_i` is a sector identifier, not a measure of firm size or performance.
- Firms with the same `G_i` belong to the same sector.
- Aggregate firm-level variables by `G_i` to calculate sector totals.
- Keep firm-level observations grouped by `G_i` to compare distributions within
  sectors, for example with box plots.

## References

- [BeforeIT ODD+D description](odd-d-description.md)
- [Eurostat A\*64 aggregation](https://ec.europa.eu/eurostat/documents/3859598/5936129/KS-GQ-13-005-EN.PDF)
- [Eurostat supply-use and input-output tables](https://ec.europa.eu/eurostat/en/web/esa-supply-use-input-tables/information-data)
