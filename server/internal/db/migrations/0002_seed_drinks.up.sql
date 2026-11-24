-- 0002_seed_drinks: a handful of starter drinks so search/reviews have data to work with.
INSERT INTO drinks (id, name, category, recipe_ingredients, recipe_instructions) VALUES
    ('11111111-1111-1111-1111-111111111111', 'Old Fashioned', 'Cocktail',
        ARRAY['bourbon', 'sugar', 'angostura bitters', 'orange peel'],
        'Muddle sugar with bitters, add bourbon over ice, stir, garnish with orange peel.'),
    ('22222222-2222-2222-2222-222222222222', 'Margarita', 'Cocktail',
        ARRAY['tequila', 'lime juice', 'triple sec', 'salt'],
        'Shake tequila, lime juice and triple sec with ice; strain into a salt-rimmed glass.'),
    ('33333333-3333-3333-3333-333333333333', 'Negroni', 'Cocktail',
        ARRAY['gin', 'campari', 'sweet vermouth'],
        'Stir equal parts over ice, strain, garnish with orange.'),
    ('44444444-4444-4444-4444-444444444444', 'Espresso Martini', 'Cocktail',
        ARRAY['vodka', 'coffee liqueur', 'espresso'],
        'Shake hard with ice and strain into a chilled coupe.'),
    ('55555555-5555-5555-5555-555555555555', 'Mojito', 'Cocktail',
        ARRAY['white rum', 'lime juice', 'mint', 'sugar', 'soda water'],
        'Muddle mint with sugar and lime, add rum and ice, top with soda.');
