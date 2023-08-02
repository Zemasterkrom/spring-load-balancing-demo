package com.zemasterkrom.videogameslibraryapplication.dao;

/**
 * Identifier constructor for the JPA DAO
 */
public class IdentifierBuilder {

    /**
     * Construct an integer identifier from a string
     * @param identifier String identifier
     * @return -1 if the string is not an integer, the corresponding integer otherwise
     */
    public static Integer buildId(String identifier) {
        if (identifier == null || !identifier.matches("^[0-9]+$")) {
            return -1;
        }

        return Integer.parseInt(identifier);
    }

    /**
     * Construire un identifiant chaîne à partir d'une chaîne
     * @param identifier Identifiant en chaîne
     * @return Chaîne vide si identifiant null, chaîne sinon
     */
    public static String buildName(String identifier) {
        if (identifier == null) {
            return "";
        }

        return identifier;
    }
}
