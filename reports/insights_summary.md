# India E2W Market: Where to Expand Next

Source: Vahan registrations for all 36 states/UTs, January 2023 to August 2026, analysed in
`sql/03_analysis.sql`. Periods are Indian financial years (April-March).

## 1. Situation

A two-wheeler EV brand wants to expand and asked four questions: how fast is electric two-wheeler (E2W)
adoption growing, in which states, who holds market share where, and which states it should prioritise next.

The market is growing steadily and has just sped up:

| FY | E2W registrations | Growth | EV penetration |
|---|---|---|---|
| FY2023-24 | 1,000,612 | | 5.49% |
| FY2024-25 | 1,210,921 | +21.0% | 6.17% |
| FY2025-26 | 1,468,093 | +21.2% | 6.62% |
| FY2026-27 (Apr-Aug) | 916,256 | +72.8% vs Apr-Aug last year | 9.90% |

## 2. Key findings

**1. Adoption is accelerating this year.**
After two years of about 21% growth, April-August 2026 is 72.8% ahead of the same months last year.
July 2026 was the highest month on record (205,801), and monthly penetration crossed 10% for the first time
in June 2026 (10.59%), reaching 11.24% in July. The market is no longer niche in the months that matter.

**2. Demand is concentrated in the South and West.**
The South accounts for 38.0% of FY2025-26 E2W volume at 10.33% penetration; the West 20.4% at 7.36%.
The top five states (Maharashtra, Karnataka, Tamil Nadu, Uttar Pradesh, Madhya Pradesh) make up 55.1% of volume.
Kerala (14.06%), Goa (13.24%) and Karnataka (13.06%) have about twice the national penetration of 6.62%,
while Uttar Pradesh is at 3.90% and Bihar at 2.37% despite their size.

**3. The fastest growth is in large states outside the traditional leaders.**
Madhya Pradesh grew 55.3% in FY2025-26, Delhi 51.4%, Odisha 42.0% and Tamil Nadu 33.5%. Maharashtra, the
largest market with 225,506 registrations, grew only 6.4%, and Telangana 6.2%. Madhya Pradesh also had the
biggest penetration gain, from 5.87% to 8.57%.

**4. Market share can move fast: Ola's collapse handed the market to legacy makers.**
Ola's national share peaked at 48.6% in Q1 FY2024-25 and fell to 11.49% for FY2025-26 (-18.3 pp on the year).
TVS (24.40%), Bajaj (20.39%), Ather (17.34%) and Hero MotoCorp's Vida (10.17%) now hold about 72% between them.
Over the last 12 months, Hero (+4.75 pp), Ather (+3.27 pp) and TVS (+2.33 pp) gained the most share.

**5. Each state is a different competitive game.**
TVS leads 6 of the 10 largest states, Bajaj leads Maharashtra (38.0%) and Gujarat, and Ather leads Kerala and
Karnataka. Maharashtra is the most concentrated market (HHI 2,245, Bajaj 17.5 pp ahead of TVS). Delhi is the most
open: HHI 966, 14 makers with at least 1% share, and a leader with only 16.6%.

**6. The festive season helps petrol two-wheelers more than EVs.**
In FY2025-26 all-2W registrations in September-November ran 45.1% above the other months, but E2W only 6.9%.
Penetration drops in those months (4.66% in October 2025). March is the strongest EV month every year.

## 3. Recommendation

The state scorecard ranks the 10 largest E2W states (82% of volume) on market size (weight 0.35), growth (0.25),
penetration headroom (0.15) and competitive openness (0.25), and tests four different weightings.

**Prioritise, in order:**
1. **Tamil Nadu**: ranks 2nd under every weighting. Third-largest market (158,628), +33.5% growth, competitive (HHI 1,493).
2. **Karnataka**: largest-volume candidate after Maharashtra (186,685), +25.7%, and 13.06% penetration,
   the highest of the three biggest markets, so the consumer is proven; ranks 1st to 4th.
3. **Delhi**: 1st on the base weights: +51.4% growth and the most fragmented market (HHI 966), but smaller
   (41,245), so it falls to 5th when size dominates. A good launch city with low entry cost.
4. **Uttar Pradesh**: 124k registrations at only 3.90% penetration, the most headroom among large states; ranks 3rd-5th.
5. **Odisha**: +42.0% growth and 10.50% penetration; 6th on base weights but 3rd when growth is weighted up.

**Deprioritise for now: Maharashtra.** It is the biggest market, but growth is 6.4%, it is the most concentrated
(Bajaj at 38%), and its rank swings from 3rd to 9th depending on the weights. Enter later, or through a partner.

**Entry approach:** launch in Tamil Nadu, Karnataka and Delhi first, where demand is proven and share is spread
across several makers; follow with Uttar Pradesh and Odisha, where growth is fastest and penetration is still low.
Time launches for the March year-end peak rather than the festive season.

## 4. Risks

- Share is volatile: Ola lost over 40 points of quarterly share in under two years. Any position can be lost quickly.
- FY2026-27 growth is based on five months; a slower second half would lower it.
- Incumbents are strong where they lead: TVS in six states, Bajaj in Maharashtra, Ather in the South.
- Policy and subsidy changes, battery costs and charging availability are outside this dataset.

## 5. Data limitations

- Vahan counts registrations, not sales. Low-speed E2W (up to 25 km/h and 250 W) need no registration and are not counted.
- September 2026 is excluded because it was incomplete at download (28 September 2026).
- Per-lakh figures use one population projection (1 October 2025) for all years.
- Maker-level state data covers the 10 largest states; the rest is a "Rest of India" bucket.
- Maker names are legal entities; renames were merged by hand (Ampere Vehicles to Greaves Electric Mobility,
  Chetak Technology to Bajaj Auto).

## 6. Next steps

- Add maker-level data for the remaining states, and RTO (district) data inside the priority states.
- Split by price segment and model to see where a new brand would compete.
- Bring in charging-station counts and state EV subsidy policies as scorecard factors.
- Refresh monthly: the pipeline re-runs from new Vahan downloads in a few minutes.
