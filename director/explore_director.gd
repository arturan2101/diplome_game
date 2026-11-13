class_name ExploreDirector
extends Director
## Collects training data for the learned director (bot simulations only,
## --mode=explore): every section gets a bandit action picked uniformly at random from
## the director's generator, so a seed replays the same choices. The action and the
## context go to the log; training/train_bandit.py learns from them. Because the choice
## does not depend on the player, every action is tried in every kind of situation.


func choose_next(state: PlayerState) -> SectionPlan:
	var plan: SectionPlan = new_plan(state)
	BanditActions.apply(self, plan, state, state.rng.randi_range(0, BanditActions.count(settings) - 1))
	return plan
