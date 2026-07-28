# 01 — Single-item Campaign provider and CampaignScreen cutover

**What to build:** A `campaignProvider(id)` — an `AsyncNotifierProvider.family` keyed by campaign id — joins the provider graph, reading the one Campaign named by its id through `Database.getCampaign` and writing through a `save(Campaign)` that updates it through the seam, invalidates itself, then invalidates `campaignListProvider` so the campaign list can never go stale after an edit made from this screen. `CampaignScreen` stops loading its Campaign by hand in `initState` and holding it in `setState`: it `ref.watch(campaignProvider(campaignId))` and renders the resulting loading/error/missing/data states directly, and its info-edit save action calls `campaignProvider(campaignId).notifier.save(...)` instead of writing through `campaignListProvider`'s notifier. A DM editing a campaign's name, setting, or description sees the change reflected immediately if they navigate back to the campaign list, with no manual refresh needed.

**Blocked by:** atomic-reorder 02 — Chapter reorder becomes atomic. Not a technical dependency (`Database.getCampaign` already exists): C3 rewrites `CampaignScreen`'s chapter-reorder call site and the same provider file, and the maintainer has sequenced C3 ahead of C4 so this ticket rebases onto the finished reorder work rather than conflicting with it.

**Status:** done

- [x] `campaignProvider` is an `AsyncNotifierProvider.family<..., Campaign?, String>` keyed by campaign id; `build(id)` calls `Database.getCampaign(id)` and returns its result, including `null`, without throwing
- [x] `campaignProvider(id).notifier.save(Campaign)` writes through `Database.updateCampaign`, calls `ref.invalidateSelf()`, then invalidates `campaignListProvider`
- [x] `CampaignScreen` no longer holds a `Campaign` in `setState`; it `ref.watch(campaignProvider(campaignId))` and renders loading / error / missing (`null`) / data explicitly
- [x] `CampaignScreen`'s info-edit save calls `campaignProvider(campaignId).notifier.save(...)`, not `campaignListProvider`'s notifier
- [x] `CampaignScreen`'s chapter add/delete/reorder call sites are untouched by this ticket — they are collection operations outside this PRD's writer rule
- [x] A `ProviderContainer` test overriding `databaseProvider` with the `InMemoryDatabase` fake (matching the existing list-notifier provider tests' pattern) covers: `build` returns the correct Campaign for a known id; `build` for an unknown id returns `null` without throwing; `save` is observable on a subsequent read of `campaignProvider(id)`; after `save`, re-reading `campaignListProvider` reflects the change (the anti-stale regression test)
- [x] `flutter analyze` clean; full `flutter test` green
- [x] Manually verified: editing a campaign's info from `CampaignScreen`, then returning to the campaign list, shows the updated name/timestamp with no stale copy
