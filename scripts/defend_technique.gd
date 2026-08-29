class_name DefendTechnique
extends Technique

func execute(user: Combatant, target: Combatant) -> String:
    user.is_defending = true

    return "%s braces to defend." % user.familiar.familiar_name